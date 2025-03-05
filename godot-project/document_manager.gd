extends Node

class_name DocumentManager

var document_map = {}
var http_request: HTTPRequest

signal document_uploaded(success: bool)
signal documents_fetched(documents: Array)

func _init():
    http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(_on_request_completed)

func upload_document(file_path: String):
    var file = FileAccess.open(file_path, FileAccess.READ)
    if !file:
        print("Failed to open file!")
        emit_signal("document_uploaded", false)
        return
        
    var file_data = file.get_buffer(file.get_length())
    file.close()
    
    # Create multipart form data
    var boundary = "GodotFormBoundary"
    var body = PackedByteArray()
    
    # Add file data
    var file_header = "\r\n--" + boundary + "\r\n"
    file_header += "Content-Disposition: form-data; name=\"file\"; filename=\"" + file_path.get_file() + "\"\r\n"
    file_header += "Content-Type: application/pdf\r\n\r\n"
    body.append_array(file_header.to_utf8_buffer())
    body.append_array(file_data)
    
    # Add original_file_path field
    var path_field = "\r\n--" + boundary + "\r\n"
    path_field += "Content-Disposition: form-data; name=\"original_file_path\"\r\n\r\n"
    path_field += file_path + "\r\n"
    body.append_array(path_field.to_utf8_buffer())
    
    # Add closing boundary
    var end_boundary = "\r\n--" + boundary + "--\r\n"
    body.append_array(end_boundary.to_utf8_buffer())
    
    # Set up headers
    var headers = [
        "Content-Type: multipart/form-data; boundary=" + boundary
    ]
    
    # Send request
    var url = "http://localhost:8000/upload"
    var error = http_request.request_raw(url, headers, HTTPClient.METHOD_POST, body)
    
    if error != OK:
        print("An error occurred while uploading the PDF")
        emit_signal("document_uploaded", false)

func fetch_documents():
    var url = "http://localhost:8000/documents"
    var error = http_request.request(url)
    
    if error != OK:
        print("Failed to fetch documents")
        emit_signal("documents_fetched", [])

func delete_document(document_name: String):
    var url = "http://localhost:8000/delete"
    var headers = ["Content-Type: application/json"]
    var body = JSON.stringify({"document_name": document_name})
    
    var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
    if error != OK:
        print("Failed to send delete request")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
    if result != HTTPRequest.RESULT_SUCCESS:
        print("Request failed with result: ", result)
        if body.size() > 0:
            print("Error message: ", body.get_string_from_utf8())
        return
    
    var json = JSON.new()
    var error = json.parse(body.get_string_from_utf8())
    
    if error == OK:
        var response = json.get_data()
        
        # Handle different response types based on the endpoint
        if "documents" in response:
            emit_signal("documents_fetched", response["documents"])
        elif "success" in response:
            emit_signal("document_uploaded", response["success"])
        
        if "message" in response:
            print("Server message: ", response["message"])
    else:
        print("Failed to parse response JSON")

func get_document_path(document_name: String) -> String:
    var project_dir = ProjectSettings.globalize_path("res://")
    return project_dir + "../server/public/" + document_name

func open_document(document_path: String, page: int = 1):
    if !FileAccess.file_exists(document_path):
        print("Document not found: ", document_path)
        return false
    
    var success = false
    
    if OS.has_feature("windows"):
        success = _open_document_windows(document_path, page)
    elif OS.has_feature("macos"):
        success = _open_document_macos(document_path, page)
    elif OS.has_feature("linux"):
        success = _open_document_linux(document_path, page)
    
    if !success:
        # Fallback to system default
        success = OS.shell_open(document_path) == OK
    
    return success

func _open_document_windows(path: String, page: int) -> bool:
    var readers = [
        {
            "name": "Adobe Acrobat",
            "paths": [
                "C:\\Program Files (x86)\\Adobe\\Acrobat Reader DC\\Reader\\AcroRd32.exe",
                "C:\\Program Files\\Adobe\\Acrobat DC\\Acrobat\\Acrobat.exe"
            ],
            "args": ["/A", "page=%d" % page, path]
        },
        {
            "name": "SumatraPDF",
            "paths": [
                OS.get_environment("ProgramFiles") + "\\SumatraPDF\\SumatraPDF.exe",
                OS.get_environment("ProgramW6432") + "\\SumatraPDF\\SumatraPDF.exe"
            ],
            "args": ["-page", str(page), path]
        }
    ]
    
    for reader in readers:
        for exe_path in reader["paths"]:
            if FileAccess.file_exists(exe_path):
                var pid = OS.create_process(exe_path, reader["args"], false)
                if pid != 0:
                    return true
    
    return false

func _open_document_macos(path: String, page: int) -> bool:
    var readers = [
        {
            "name": "Preview",
            "script": """
            tell application "Preview" to open POSIX file "%s"
            delay 1
            tell application "System Events" to tell process "Preview"
                keystroke "g" using {command down, option down}
                delay 0.5
                keystroke "%d"
                keystroke return
            end tell
            """ % [path, page]
        }
    ]
    
    for reader in readers:
        if reader.has("script"):
            var result = OS.execute("osascript", ["-e", reader["script"]])
            if result == 0:
                return true
    
    return false

func _open_document_linux(path: String, page: int) -> bool:
    var readers = [
        {
            "name": "Evince",
            "cmd": "evince",
            "args": ["-p", str(page), path]
        },
        {
            "name": "Okular",
            "cmd": "okular",
            "args": ["-p", str(page), path]
        },
        {
            "name": "qpdfview",
            "cmd": "qpdfview",
            "args": ["--page", str(page), path]
        }
    ]
    
    for reader in readers:
        var exit_code = OS.execute("which", [reader["cmd"]])
        if exit_code == 0:
            var pid = OS.create_process(reader["cmd"], reader["args"], false)
            if pid != 0:
                return true
    
    return false