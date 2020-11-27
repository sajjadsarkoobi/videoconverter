# videoconverter
Video Converter based on [AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter)

## Predefined bitrtes:
video bit rates |
--- |
12.5
25
30
Default of current video

## Predefined video output size
video outputs |
--- |
videoSize 640x480
videoSize 960x540
videoSize 1280x720
videoSize 1920x1080

## Delegates
```swift
protocol VideoConverterDelegate: AnyObject {
    func videoConverterFinished(url:URL)
    func videoConverterFinished(data:Data)
    func videoConverterCanceled(error: videoConverterError)
}
```

## Errors
```swift
enum videoConverterError:String,Error {
    case inputFileError = "Input file error"
    case assetReaderInitErr = "Could not iniitalize asset reader probably"
    case audioOutputError = "Couldn't add audio output reader"
    case videoOutputError = "Couldn't add video output reader"
    case assetWriterError = "Asset writer was nil"
    case urlCreationFailed = "Failed to retrive URL of file"
    case dataCreationFailed = "Faild to create data from video"
}
```

## Author
Sajjad Sarkoobi

sajjadsarkoobi@gmail.com

https://www.linkedin.com/in/sajjad-sarkoobi/
