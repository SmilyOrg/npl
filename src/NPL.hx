package ;

import haxe.Http;
import haxe.io.Bytes;
import haxe.Json;
import haxe.Resource;
import haxe.Timer;
import mcli.CommandLine;
import mcli.Dispatch;
import sys.io.File;
import sys.io.Process;

using StringTools;

typedef Track = {
	artist:String,
	name:String,
	album:String,
	image:String,
	mbid:String,
}

enum Error {
	KeyMissing;
	UserMissing;
	IntervalRange;
}

/**
 * npl (Now PLaying)
 * 
 * Grabs now playing data from last.fm and provides it via CLI output and as files on the file system.
 * Default album art "Circular auriculars" is CC BY 3.0 by GraphBerry.
 * 
 * Usage: npl USER
 */
class NPL extends CommandLine {
	
	/**
	 * Use a custom last.fm API key, a default one is provided for compiled binaries.
	 * 
	 * @alias k
	 */
	public var key:String = "";
	
	
	/**
	 * Path to the file that should contain the currently playing track name.
	 * The track name is empty if there is nothing currently playing.
	 * 
	 * @alias i
	 */
	public var info:String = "nowplaying.txt";
	
	
	/**
	 * Path to the image file that should contain the album art of the currently playing track.
	 * If the track doesn't have associated album art or if there is nothing playing, a default one is provided.
	 * 
	 * @alias m
	 */
	public var image:String = "cover.jpg";
	
	
	/**
	 * Custom default image to use instead of the built-in one.
	 * 
	 * @alias d
	 */
	public var imageDefault:String = "";
	
	
	/**
	 * Interval of polling updates in seconds. 
	 * 
	 * @alias s
	 */
	public var interval:Float = 10;
	
	var user = "";
	
	var intervalMinimum = 1;
	var imageDefaultBytes:Bytes;
	
	var http = new Http("");
	var track:Null<Track> = null;
	var trackUpdated:Float = 0;
	
	
	static function main() {
		new mcli.Dispatch(Sys.args()).dispatch(new NPL());
	}
	
	/**
	 * Print this help message.
	 * @alias h
	 */
	public function help() {
		Sys.println(this.showUsage());
		Sys.exit(0);
	}
	
	public function runDefault(user:String) {
		if (key == "") {
			key = Resource.getString("key");
			if (key == "") {
				abort(KeyMissing);
			}
		}
		if (user == "") abort(UserMissing);
		this.user = user;
		if (interval < intervalMinimum) abort(IntervalRange);
		imageDefaultBytes = imageDefault == "" ? Resource.getBytes("default") : File.getBytes(imageDefault);
		Sys.println('HELLO: $user');
		loop();
	}
	
	
	
	function abort(e:Error) {
		var d = switch (e) {
			case KeyMissing: { c: 1, m: "API key was not provided and the default key is missing (see src/assets/key.txt)."};
			case UserMissing: { c: 2, m: "Missing or empty user name."};
			case IntervalRange: { c: 3, m: "Interval of ${interval}s out of range. Intervals shorter than ${intervalMinimum}s not supported."};
		};
		error(d.m);
		Sys.exit(d.c);
	}
	
	function error(msg:String) {
		Sys.stderr().writeString("ERROR: "+msg+"\n");
		return null;
	}
	
	function log(v:Dynamic) {
		Sys.println(v);
	}
	
	function title(msg:String) {
		Sys.stdout().writeString(ANSI.title(msg));
	}
	
	function getURL():String {
		return 'http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&format=json&limit=1&user=${user.urlEncode()}&api_key=${key}';
	}
	
	
	
	function loop() {
		while (true) {
			update();
			Sys.sleep(interval);
		}
	}
	
	function update() {
		http = new Http(getURL());
		http.onError = onError;
		http.onData = process;
		http.request();
	}
	
	function cleanup() {
		if (http != null) {
			http.onError = null;
			http.onData = null;
			http = null;
		}
	}
	
	function onError(msg:String) {
		cleanup();
		error('Error accessing API: $msg');
	}
	
	function process(data:String) {
		cleanup();
		var lastTrack = track;
		track = parse(data);
		if (!trackEquals(lastTrack, track) || trackUpdated == 0) {
			writeLocal(track);
			trackUpdated = Timer.stamp();
		}
		refreshStatus();
	}
	
	function trackEquals(a:Null<Track>, b:Null<Track>) {
		if (a == null && b == null) return true;
		if (a == null) return false;
		if (b == null) return false;
		return {
			a.album == b.album &&
			a.artist == b.artist &&
			a.image == b.image &&
			a.mbid == b.mbid &&
			a.name == b.name;
		}
	}
	
	function parse(data:String):Null<Track> {
		var d = Json.parse(data);
		
		if (d.error != null) return error('API Error: ${d.message}');
		
		var tracks = d.recenttracks.track;
		
		if (tracks == null) return error('Tracks not found');
		var track:Dynamic = Std.is(tracks, Array) ? tracks[0] : tracks;
		
		if (track == null) return error('Track not found');
		
		var attr = Reflect.field(track, "@attr");
		
		if (attr == null || attr.nowplaying != "true") {
			return null;
		}
		
		return {
			artist: track.artist == null ? "" : Reflect.field(track.artist, "#text"),
			name: track.name == null ? "" : track.name,
			album: track.album == null ? "" : Reflect.field(track.album, "#text"),
			image: {
				var len = (track.image:Array<Dynamic>).length;
				track.image == null || len == 0 ? "" : Reflect.field(track.image[len-1], "#text");
			},
			mbid: track.mbid == null ? "" : track.mbid,
		};
	}
	
	function writeLocal(track:Null<Track>) {
		var output = getOutput(track);
		var out = File.write(info, false);
		out.writeString(output);
		out.close();
		log('TRACK: $output');
		if (track != null && track.image != "") {
			var url = track.image.replace(" ", "+");
			var wget = new Process("wget", [url, "-O", image]);
			if (wget.exitCode() == 0) {
				log('IMAGE: $url');
			} else {
				error('Failed to wget image: $url');
			}
		} else {
			var out = File.write(image);
			out.writeBytes(imageDefaultBytes, 0, imageDefaultBytes.length);
			out.close();
		}
	}
	
	function getOutput(track:Track):String {
		if (track == null) return " ";
		var output = track.name;
		if (track.artist != "") output += " - "+track.artist;
		if (track.album != "") output += " - "+track.album;
		output += "   ";
		return output;
	}
	
	function refreshStatus() {
		var delta = Timer.stamp()-trackUpdated;
		var seconds = (""+Math.floor(delta)%60).lpad("0", 2);
		var minutes = Math.floor(delta/60);
		var hours = Math.floor(delta/60/60);
		var output = track == null ? "[silence]" : getOutput(track);
		title('[' + (hours > 0 ? '$hours:' : '')+'$minutes:$seconds]   $output');
	}
	
}