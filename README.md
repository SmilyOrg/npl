npl
===

Now PLaying polls the currently playing track from last.fm and saves it as a text file along with an album art image.

## Examples

Simplest usage case, writes my currently playing track to `nowplaying.txt` and the album art to `cover.jpg`, updating every 10 seconds.
```
npl SmilyOrg
```

Saves track name into `track.txt`, album art into `album.jpg`, uses `default.png` as the default album art and is set to update every 2 seconds.
```
npl SmilyOrg -i track.txt -m album.jpg -d default.png -s 2
```

## Usage

```
npl (Now PLaying) 
 
Grabs now playing data from last.fm and provides it via CLI output and as files on the file system. 
 
Default album art "Circular auriculars" is CC BY 3.0 by GraphBerry. 
 
Usage: npl USER
 
  -k, --key <key>                  Use a custom last.fm API key, a default one 
                                   is provided for compiled binaries.  
  -i, --info <info>                Path to the file that should contain the 
                                   currently playing track name. The track name is empty 
                                   if there is nothing currently playing.  
  -m, --image <image>              Path to the image file that should contain 
                                   the album art of the currently playing track. 
                                   If the track doesn't have associated album art 
                                   or if there is nothing playing, a default one 
                                   is provided.  
  -d, --image-default <imageDefault>
                                 Custom 
                                   default image to use instead of the built-in one.  
  -s, --interval <interval>        Interval of polling updates in seconds. 
  -h, --help                       Print this help message. 
```
