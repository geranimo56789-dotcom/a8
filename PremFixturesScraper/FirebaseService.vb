Imports System.Net.Http
Imports System.Text
Imports System.Threading.Tasks
Imports Newtonsoft.Json

Public Module FirebaseService
    Private Const FirebaseProject As String = "var6-51392"
    Private Const ApiKey As String = "AIzaSyC2kZjQtro_hKd-TZRBTlXfqE9Fj4_PqUA" 
    Private ReadOnly BaseUrl As String = $"https://firestore.googleapis.com/v1/projects/{FirebaseProject}/databases/(default)/documents"
    Private ReadOnly AuthParam As String = $"?key={ApiKey}"

    Public Async Function DeleteAllFixtures() As Task
        Dim client As New HttpClient()
        Dim path As String = "fixtures"
        Dim nextPageToken As String = Nothing

        Do
            Dim listUrl As String = $"{BaseUrl}/{path}{AuthParam}"
            If Not String.IsNullOrEmpty(nextPageToken) Then
                listUrl &= $"&pageToken={nextPageToken}"
            End If

            Dim response = Await client.GetAsync(listUrl)
            response.EnsureSuccessStatusCode()
            Dim json = Await response.Content.ReadAsStringAsync()
            Dim documentList = JsonConvert.DeserializeObject(Of DocumentList)(json)

            If documentList.documents IsNot Nothing Then
                For Each doc In documentList.documents
                    Dim docId = doc.name.Split("/"c).Last()
                    Dim deleteUrl As String = $"{BaseUrl}/fixtures/{docId}{AuthParam}"
                    Dim deleteResponse = Await client.DeleteAsync(deleteUrl)
                    deleteResponse.EnsureSuccessStatusCode()
                Next
            End If
            nextPageToken = documentList.nextPageToken
        Loop While Not String.IsNullOrEmpty(nextPageToken)
    End Function

    Public Async Function UploadFixtures(fixtures As List(Of String)) As Task
        Dim client As New HttpClient()
        For i As Integer = 0 To fixtures.Count - 1
            Dim fixture = fixtures(i)
            Dim fullUrl As String = $"{BaseUrl}/fixtures{AuthParam}"

            Dim payload As New With {
                .fields = New With {
                    .line = New With {
                        .stringValue = fixture
                    },
                    .orderIndex = New With {
                        .integerValue = i
                    }
                }
            }
            Dim jsonPayload = JsonConvert.SerializeObject(payload)
            Dim content = New StringContent(jsonPayload, Encoding.UTF8, "application/json")

            Dim response = Await client.PostAsync(fullUrl, content)
            response.EnsureSuccessStatusCode()
        Next
    End Function

    Public Class DocumentList
        Public Property documents As List(Of Document)
        Public Property nextPageToken As String
    End Class

    Public Class Document
        Public Property name As String
    End Class
End Module
