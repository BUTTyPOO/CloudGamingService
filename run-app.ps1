param ($path,$appfile,$isSandbox,$hostIP,$vcodec)

if ([string]::IsNullOrEmpty($hostIP)) {
    $hostIP = '127.0.0.1';
}
# Split-Path $outputPath -leaf
echo "running $PSScriptRoot/winvm/$path/$appfile"

taskkill /FI "ImageName eq $appfile" /F
taskkill /FI "ImageName eq ffmpeg.exe" /F
taskkill /FI "ImageName eq syncinput.exe" /F
$app = Start-Process "$PSScriptRoot/winvm/$path/$appfile" -PassThru
sleep 2
$title = ((Get-Process -Id $app.id).mainWindowTitle)
sleep 2

# ffmpeg setup
    $ffmpegParams = -join @(
        "-f gdigrab -framerate 60 -video_size 1920x1080 -i desktop -pix_fmt yuv420p "
        if ( 'h264' -eq $vcodec )
            { "-c:v libx264 -tune zerolatency -preset ultrafast -crf 30 -x264opts keyint=120:no-scenecut -vsync 0 " } else
            { "-c:v libvpx -deadline realtime -quality realtime -crf 4 " }
        "-vf scale=852:480 "
        "-f rtp rtp://127.0.0.2:5004 "
    )
    echo "encoding params: "$ffmpegParams

if ($isSandbox -eq "sandbox") {
    Start-Process $PSScriptRoot/winvm/pkg/ffmpeg/ffmpeg.exe -PassThru -NoNewWindow -ArgumentList "$ffmpegParams"
    sleep 2
    while ($true) {
        Start-Process -Wait $PSScriptRoot/winvm/syncinput.exe -PassThru -NoNewWindow -ArgumentList "$title", ".", "windows", $hostIP
    }
    # Restart on failure. Using service to restart on failure, not working now
    # $syncinput = New-Service -Name "Syncinput" -BinaryPathName "$PSScriptRoot\winvm\syncinput.exe $title . windows $hostIP"
    # sc failure Syncinput reset= 30 actions= restart/5000
    # $syncinput.Start()
}
else {    
    Start-Process ffmpeg -PassThru -ArgumentList "$ffmpegParams"
    sleep 2
    Start-Process -PassThru $PSScriptRoot/winvm/syncinput.exe -ArgumentList "$title", ".", "windows"
}
