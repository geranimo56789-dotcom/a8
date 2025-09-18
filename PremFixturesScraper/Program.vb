Imports System
Imports System.IO
Imports System.Net.Http
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Threading
Imports OpenQA.Selenium
Imports OpenQA.Selenium.Edge
Imports System.Collections.Generic

Module Program
    Private ReadOnly WorkDir As String = Path.Combine(AppContext.BaseDirectory, "scrape_data")
    Private ReadOnly RawPath As String = Path.Combine(WorkDir, "raw.txt")
    Private ReadOnly FixturesPath As String = Path.Combine(WorkDir, "fixtures_parsed.txt")
    Private ReadOnly ErrorsPath As String = Path.Combine(WorkDir, "errors.txt")
    Private ReadOnly LogPath As String = Path.Combine(WorkDir, "log.txt")

    Sub Main()
        Try
            Directory.CreateDirectory(WorkDir)
            Log("Start run")
            Dim url As String = "https://www.premierleague.com/en/news/4324539/all-380-fixtures-for-202526-premier-league-season"
            Dim gotText As Boolean = FetchVisibleText(url, RawPath)
            If Not gotText Then
                Log("Selenium failed or blocked. Trying HTTP fallback")
                Dim html As String = FetchHtml(url, 20000)
                If html Is Nothing Then
                    File.AppendAllText(ErrorsPath, $"{Timestamp()} | FETCH | Both Selenium and HTTP failed{Environment.NewLine}", New UTF8Encoding(False))
                    Log("Fetch failed; exiting")
                    Return
                End If
                Dim rough As String = HtmlToRoughText(html)
                File.WriteAllText(RawPath, rough, New UTF8Encoding(False))
                Log("Wrote rough text from HTML")
            End If

            Dim fixtures = ParseRawToFixtures(RawPath, ErrorsPath, url)
            If fixtures.Count > 0 Then
                Log($"Got {fixtures.Count} fixtures. UPLOADING to Firebase.")
                fixtures.Insert(0, $"(Refreshed on {DateTime.Now:yyyy-MM-dd HH:mm})")
                FirebaseService.DeleteAllFixtures().Wait()
                FirebaseService.UploadFixtures(fixtures).Wait()
                Log("Firebase upload complete.")
            Else
                Log("No fixtures parsed. Nothing to upload.")
            End If
            Log("Done")
        Catch ex As Exception
            Log($"FATAL: {ex.ToString()}")
            File.AppendAllText(ErrorsPath, $"{Timestamp()} | FATAL | {ex.ToString()}{Environment.NewLine}", New UTF8Encoding(False))
        End Try
    End Sub

    Private Function FetchVisibleText(pageUrl As String, outputPath As String) As Boolean
        Try
            Dim driverExe As String = Path.Combine(AppContext.BaseDirectory, "msedgedriver.exe")
            If Not File.Exists(driverExe) Then
                Return False
            End If
            Dim service As EdgeDriverService = EdgeDriverService.CreateDefaultService(Path.GetDirectoryName(driverExe), Path.GetFileName(driverExe))
            service.HideCommandPromptWindow = True
            Dim options As New EdgeOptions()
            options.AddArgument("--headless=new")
            options.AddArgument("--disable-gpu")
            options.AddArgument("--window-size=1280,2400")
            options.PageLoadStrategy = PageLoadStrategy.Normal

            Using driver As New EdgeDriver(service, options, TimeSpan.FromSeconds(30))
                driver.Manage().Timeouts().PageLoad = TimeSpan.FromSeconds(30)
                driver.Navigate().GoToUrl(pageUrl)
                Dim js = CType(driver, IJavaScriptExecutor)
                Dim start As DateTime = DateTime.UtcNow
                Dim text As String = ""
                Do
                    Try
                        text = CStr(js.ExecuteScript("return (document.body && document.body.innerText) ? document.body.innerText : '';"))
                    Catch
                        text = ""
                    End Try
                    If Not String.IsNullOrWhiteSpace(text) AndAlso text.Length > 3000 Then Exit Do
                    Thread.Sleep(500)
                Loop While (DateTime.UtcNow - start).TotalSeconds < 20
                If String.IsNullOrWhiteSpace(text) Then Return False
                File.WriteAllText(outputPath, text, New UTF8Encoding(False))
                Return True
            End Using
        Catch ex As Exception
            File.AppendAllText(ErrorsPath, $"{Timestamp()} | SELENIUM | {ex.Message}{Environment.NewLine}", New UTF8Encoding(False))
            Return False
        End Try
    End Function

    Private Function FetchHtml(url As String, timeoutMs As Integer) As String
        Try
            Dim handler As New HttpClientHandler() With { .AllowAutoRedirect = True, .AutomaticDecompression = Net.DecompressionMethods.GZip Or Net.DecompressionMethods.Deflate }
            Using http As New HttpClient(handler)
                http.Timeout = TimeSpan.FromMilliseconds(timeoutMs)
                http.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36 VB.NET-Scraper/1.0")
                Return http.GetStringAsync(url).GetAwaiter().GetResult()
            End Using
        Catch ex As Exception
            File.AppendAllText(ErrorsPath, $"{Timestamp()} | HTTP | {ex.Message}{Environment.NewLine}", New UTF8Encoding(False))
            Return Nothing
        End Try
    End Function

    Private Function HtmlToRoughText(html As String) As String
        Dim s As String = Regex.Replace(html, "<script[\s\S]*?</script>", "", RegexOptions.IgnoreCase)
        s = Regex.Replace(s, "<style[\s\S]*?</style>", "", RegexOptions.IgnoreCase)
        s = Regex.Replace(s, "<br\s*/?>", Environment.NewLine, RegexOptions.IgnoreCase)
        s = Regex.Replace(s, "</(p|div|li|h\d)>", Environment.NewLine, RegexOptions.IgnoreCase)
        s = Regex.Replace(s, "<[^>]+>", " ")
        s = Regex.Replace(s, "\s{2,}", " ").Trim()
        Return s
    End Function

    Private Function ParseRawToFixtures(rawPath As String, errorsPath As String, sourceUrl As String) As List(Of String)
        Dim lines As String() = File.ReadAllLines(rawPath, Encoding.UTF8)
        Dim baseYear As Integer = InferBaseYear(lines, sourceUrl)
        Dim monthToNum As New Dictionary(Of String, Integer)(StringComparer.OrdinalIgnoreCase) From {
            {"January", 1}, {"February", 2}, {"March", 3}, {"April", 4}, {"May", 5}, {"June", 6},
            {"July", 7}, {"August", 8}, {"September", 9}, {"Sept", 9}, {"October", 10}, {"November", 11}, {"December", 12}
        }
        Dim teamMap As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase) From {
            {"Spurs", "Tottenham Hotspur"},
            {"Wolves", "Wolverhampton Wanderers"},
            {"Nott'm Forest", "Nottingham Forest"},
            {"Brighton", "Brighton & Hove Albion"},
            {"West Ham", "West Ham United"}
        }

        Dim currentIsoDate As String = Nothing
        Dim currentDayName As String = Nothing
        Dim parsedFixtures As New List(Of String)

        For Each raw In lines
            Dim line As String = NormalizeSpaces(raw.Trim())
            If line.Length = 0 Then Continue For
            If Regex.IsMatch(line, "^\s*(Matchweek|MW)\b", RegexOptions.IgnoreCase) Then Continue For
            If line.StartsWith("*") Then Continue For
            If IsNoise(line) Then Continue For

            Dim m = Regex.Match(line, "^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|Sept|October|November|December)\b", RegexOptions.IgnoreCase)
            If m.Success Then
                Dim dayName As String = CultureFix(m.Groups(1).Value)
                Dim dayNum As Integer = Integer.Parse(m.Groups(2).Value)
                Dim monthName As String = CultureFix(m.Groups(3).Value)
                If Not monthToNum.ContainsKey(monthName) Then
                    File.AppendAllText(errorsPath, $"{Timestamp()} | DATE | Unknown month: {line}{Environment.NewLine}", New UTF8Encoding(False))
                    Continue For
                End If
                Dim month As Integer = monthToNum(monthName)
                Dim year As Integer = If(month >= 8, baseYear, baseYear + 1)
                currentIsoDate = $"{year:D4}-{month:D2}-{dayNum:D2}"
                currentDayName = dayName
                Continue For
            End If

            Dim timeVal As String = "TBA"
            Dim matchPart As String = line
            Dim t = Regex.Match(line, "^(?<t>\d{1,2}:\d{2})\s+(?<rest>.+)$")
            If t.Success Then
                timeVal = t.Groups("t").Value
                matchPart = t.Groups("rest").Value.Trim()
            End If
            matchPart = Regex.Replace(matchPart, "\s+\([^)]+\)\s*$", "").Trim()
            matchPart = NormalizeSpaces(matchPart)

            Dim team1 As String = Nothing, team2 As String = Nothing
            If TrySplitTeams(matchPart, team1, team2) Then
                If String.IsNullOrEmpty(currentIsoDate) OrElse String.IsNullOrEmpty(currentDayName) Then
                    File.AppendAllText(errorsPath, $"{Timestamp()} | MATCH | No current date context | {line}{Environment.NewLine}", New UTF8Encoding(False))
                    Continue For
                End If
                team1 = NormalizeTeam(team1, teamMap)
                team2 = NormalizeTeam(team2, teamMap)
                parsedFixtures.Add($"{currentIsoDate}/{timeVal}/{currentDayName}/{team1}/{team2}")
                Continue For
            End If
        Next
        Return parsedFixtures
    End Function

    Private Function NormalizeSpaces(s As String) As String
        Return Regex.Replace(s, "\s{2,}", " ").Trim()
    End Function

    Private Function CultureFix(s As String) As String
        If String.IsNullOrEmpty(s) Then Return s
        Return Char.ToUpperInvariant(s(0)) & s.Substring(1).ToLowerInvariant()
    End Function

    Private Function TrySplitTeams(s As String, ByRef team1 As String, ByRef team2 As String) As Boolean
        Dim candidates As String() = {" v ", " vs ", " vs. ", " v. ", "  ", "  "}
        For Each sep In candidates
            Dim idx As Integer = s.IndexOf(sep, StringComparison.OrdinalIgnoreCase)
            If idx > 0 Then
                team1 = s.Substring(0, idx).Trim()
                team2 = s.Substring(idx + sep.Length).Trim()
                Return team1.Length > 0 AndAlso team2.Length > 0
            End If
        Next
        Return False
    End Function

    Private Function NormalizeTeam(name As String, map As Dictionary(Of String, String)) As String
        Dim trimmed As String = NormalizeSpaces(name)
        For Each kvp In map
            If String.Equals(trimmed, kvp.Key, StringComparison.OrdinalIgnoreCase) Then
                Return kvp.Value
            End If
        Next
        Return trimmed
    End Function

    Private Function IsNoise(line As String) As Boolean
        If line.Length > 80 AndAlso line.Contains("_WebPage_") Then Return True
        If line.IndexOf("Kick-off times", StringComparison.OrdinalIgnoreCase) >= 0 Then Return True
        If line.IndexOf("All times", StringComparison.OrdinalIgnoreCase) >= 0 Then Return True
        Return False
    End Function

    Private Function InferBaseYear(lines As String(), url As String) As Integer
        Dim m = Regex.Match(String.Join(" ", lines), "(\d{4})/(\d{2})")
        If m.Success Then
            Dim y As Integer = Integer.Parse(m.Groups(1).Value)
            If y >= 1990 AndAlso y <= 2100 Then Return y
        End If
        Dim fromUrl = Regex.Match(url, "(20\d{2})(\d{2})")
        If fromUrl.Success Then
            Return Integer.Parse(fromUrl.Groups(1).Value)
        End If
        Dim nowY As Integer = DateTime.UtcNow.Year
        Return If(DateTime.UtcNow.Month >= 8, nowY, nowY - 1)
    End Function

    Private Sub Log(msg As String)
        File.AppendAllText(LogPath, $"{Timestamp()} | {msg}{Environment.NewLine}", New UTF8Encoding(False))
    End Sub

    Private Function Timestamp() As String
        Return DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    End Function
End Module
