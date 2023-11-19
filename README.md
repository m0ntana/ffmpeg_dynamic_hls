# ffmpeg_dynamic_hls
This project exists for educational purposes.

It shows how to use `nginx` + `bash` + `ffmpeg` to build a system which can produce HLS stream "on-fly" without need to transcode original video file (movie?) and store its copy.

# Why?
Well, I have Sony TV with "SS Player" for example.  
Sony TV by itself does not have some video/audio codecs, so I had to transcode movies after downloading them from torrents.  
To avoid that I decided to implement something similar to HLS, but without need to have a copy of video file.

# Our main targets
* have a single instance of media file in common format like: `avi`, `mkv`, `mp4`, etc.
* serve this file as HLS
* **do not** store copy of original file
* implement it as easy as possible without writing any code on python or C

# How?
### ffmpeg part
What HLS format is?  
Basically, it is M3U8 formatted playlist with video chunks and timings. In general when `hls` or `segment` muxer used - ffmpeg will encode (using selected video/audio codecs) file and split it by chunks (segments)
starting every other with key frame. And this makes sense. But in common situations like watching pirated movie on TV - we don't need this. Even on rewind in case there is no key frame in the beggining of chunk - we will see
some artifacts, but key frame will be met soon.

So what is our main task?  
Our main task is to handle HTTP requests and pass chunks of original movie as a HLS segments. Which means every chunk is N seconds offset of the beggining and K seconds length.  
`ffmpeg` can do this. Basically we have to use `-ss` option for input file and `-t` option for output. Here is an example:
```
ffmpeg -ss 1000 -i some_file.mkv -c copy -t 10 -f mpegts output.ts
```
Here we ask `ffmpeg` to skip first 1000 second and then convert 10 seconds of video to MPEGTS format without changing audio/video codecs.

Next step is to actually transcode our file to well-known codecs:
```
ffmpeg -ss 1000 -i some_file.mkv \
-c:v libx264 -preset ultrafast -tune film -x264-params keyint=60:min-keyint=2 -pix_fmt yuv420p \
-c:a aac -ar 44100 -sample_fmt fltp \
-t 10
-f mpegts output.ts
```
At this point `output.ts` will have 10 seconds of h264 video and aac audio in mpegts format.

### what is wrong?
First problem is PTS  
Every time you generate a segment in a way explained above - PTS will reset to zero. Which is not acceptable for any media player.
Let's fix this:
```
ffmpeg -ss 1000 -i some_file.mkv \
-c:v libx264 -preset ultrafast -tune film -x264-params keyint=60:min-keyint=2 -pix_fmt yuv420p \
-c:a aac -ar 44100 -sample_fmt fltp \
-t 10
-f mpegts -output_ts_offset 1000 output.ts
```
We've added `-output_ts_offset` option which will set PTS to the same offset (in seconds) we have our part of file.

Second problem is more complex. When you ask `ffmpeg` to seek to specific offset it will start transcoding from the first key frame it finds. But we will need all frames since every segment is the part of the whole stream and 
you will only notice a problem in case of rewind stream to specific timestamp. Here is a fix:
```
ffmpeg -ss 1000 -i some_file.mkv \
-c:v libx264 -preset ultrafast -tune film -x264-params keyint=60:min-keyint=2 -pix_fmt yuv420p \
-c:a aac -ar 44100 -sample_fmt fltp \
-t 10
-f mpegts -output_ts_offset 1000 -copyinkf output.ts
```
We've added `-copyinkf` option. It will force `ffmpeg` to not skip non-key frames in the beggining of chunk. 

### final version of ffmpeg command
I have years of experience with `ffmpeg`, so my complete `ffmpeg` options list looks so:
```
    ffmpeg -hide_banner -err_detect ignore_err -y \
    -ss $OFFSET -fflags +genpts -i "$INPUT" \
    -dn -sn \
    -filter_complex \
    "[0:v]scale=${VIDEOW}:${VIDEOH}:force_original_aspect_ratio=decrease,pad=${VIDEOW}:${VIDEOH}:\(ow-iw\)/2:\(oh-ih\)/2,setsar=1,fps[vout]" \
    -filter_complex \
     "[0:a]pan=stereo|FL=FC+0.30*FL+0.30*BL|FR=FC+0.30*FR+0.30*BR,
      loudnorm=I=-16:TP=-1.5:LRA=11,
      dynaudnorm=p=1/sqrt(2):m=100:s=12:g=15[aout]" \
    -c:v libx264 -preset ultrafast -tune film -x264-params keyint=60:min-keyint=2 -pix_fmt yuv420p \
    -c:a aac -ar 44100 -sample_fmt fltp \
    -t $LENGTH \
    -map [vout] -map [aout] \
    -copyinkf:[vout] \
    -f mpegts -mpegts_flags +initial_discontinuity+resend_headers -output_ts_offset $OFFSET \
    -
```
You will find it in `segment.sh` file
