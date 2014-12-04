package com.kaltura.kdpfl.view.media
{
	import com.kaltura.kdpfl.controller.media.LiveStreamCommand;
	import com.kaltura.kdpfl.model.ConfigProxy;
	import com.kaltura.kdpfl.model.MediaProxy;
	import com.kaltura.kdpfl.model.PlayerStatusProxy;
	import com.kaltura.kdpfl.model.SequenceProxy;
	import com.kaltura.kdpfl.model.type.EnableType;
	import com.kaltura.kdpfl.model.type.NotificationType;
	import com.kaltura.kdpfl.model.type.StreamerType;
	import com.kaltura.kdpfl.util.SharedObjectUtil;
	import com.kaltura.kdpfl.view.RootMediator;
	import com.kaltura.kdpfl.view.controls.KTrace;
	
	import flash.display.DisplayObject;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	import flash.utils.setTimeout;
	
	import mx.utils.Base64Encoder;
	
	import org.osmf.elements.ProxyElement;
	import org.osmf.events.AlternativeAudioEvent;
	import org.osmf.events.AudioEvent;
	import org.osmf.events.BufferEvent;
	import org.osmf.events.DisplayObjectEvent;
	import org.osmf.events.DynamicStreamEvent;
	import org.osmf.events.LoadEvent;
	import org.osmf.events.MediaElementEvent;
	import org.osmf.events.MediaErrorEvent;
	import org.osmf.events.MediaPlayerCapabilityChangeEvent;
	import org.osmf.events.MediaPlayerStateChangeEvent;
	import org.osmf.events.SeekEvent;
	import org.osmf.events.TimeEvent;
	import org.osmf.media.MediaElement;
	import org.osmf.media.MediaPlayer;
	import org.osmf.media.MediaPlayerSprite;
	import org.osmf.media.MediaPlayerState;
	import org.osmf.traits.DVRTrait;
	import org.osmf.traits.DynamicStreamTrait;
	import org.osmf.traits.MediaTraitType;
	import org.osmf.traits.TimeTrait;
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.mediator.Mediator;
	
	
	/**
	 * Mediator for the KMediaPlayer component 
	 * 
	 */	
	public class KMediaPlayerMediator extends Mediator
	{
		public static const NAME:String = "kMediaPlayerMediator";
		public var isInSequence : Boolean = false;
		
		private const PLAYING:String = "playing";
		private const PAUSED:String = "paused";
		
		private var _bytesLoaded:Number;//keeps loaded bytes for intelligent seeking
		private var _bytesTotal:Number;//keeps total bytes for intelligent seeking
		private var _duration:Number;//keeps duration for intelligent seeking
		private var _blockThumb : Boolean = false;
		private var _mediaProxy : MediaProxy; 
		private var _sequenceProxy : SequenceProxy;
		/**
		 * intelli seek offset 
		 */		
		private var _offset:Number=0
		private var _loadedTime:Number;
		private var _flashvars:Object;
		private var _seekUrl:String;
		private var _autoMute:Boolean=false;
		private var _isIntelliSeeking :Boolean=false;
		private var _lastCurrentTime:Number = 0;
		private var _newdDuration:Number;
		private var _autoPlay : Boolean;
		/**
		 * indicates if first "playing" state for playing the current media was called 
		 */		
		private var _hasPlayed : Boolean = false;
		private var _playerReadyOrEmptyFlag : Boolean = false;
		public var playBeforeMixReady : Boolean = true;
		private var _mixLoaded : Boolean = false;
		private var _prevState : String;
		/**
		 * the previous player volume 
		 */		
		private var _prevVolume:Number = 1;
	
		/**
		 * This flag fix OSMF issue that on playend you get somtimes MediaPlayerReady
		 * so to fix this I added this flag 
		 */        
		private var _loadMediaOnPlay : Boolean = false;
		
		/**
		 * Flag indicating if do_switch was explicity call, this means we should set autoDynamicStreamSwitch to false 
		 */		
		private var _doSwitchSent:Boolean = false;
		
		/**
		 * timer to get video metadata 
		 */		
		private var _metadataTimer:Timer;
		
		/**
		 * indicates if the "doSeek" was sent before "doPlay" and KDP intiate the "doPlay" in order to load the entry. 
		 */		
		private var _isPrePlaySeek:Boolean = false;
		/**
		 * indicates if we are in the middle of "pre play seek"
		 * to solve issues with pre sequence two flags were required (_isPrePlaySeek and _isPrePlaySeekInProgress) 
		 */		
		private var _isPrePlaySeekInProgress:Boolean = false;
		/**
		 * last entry duration recieved from durationChanged, will be used in intelliseek 
		 */		
		public var entryDuration:Number;
		/**
		 * where to start play of current media. Will be used when we performed "doSeek" before first play and we had a preroll - this
		 * field will remember where we requested to seek to .
		 * This field is "stronger" than _medixProxy.vo.mediaPlayFrom
		 */		
		private var _mediaStartPlayFrom:Number = -1;
		/**
		 * indicates if we are in the process of re-loading live stream entry 
		 */		
		private var _reloadingLiveStream:Boolean = false;
		/**
		 *indicates of we should listen for mediaElementReady 
		 */		
		private var _waitForMediaElement:Boolean = false;
		/**
		 * in case of mp4 intelliseek we will have to add this value to playhead position 
		 */		
		
		/**
		 * flag to indicate if change media occur
		*/
		private var _changeMediaOccur:Boolean = false;
		private var _offsetAddition:Number = 0;
		
		/**
		 * flag that indicates if we need to send seekEnd event
		 */
		private var _isAfterSeek:Boolean = false;
		
		/**
		 * flag that indicates if we are playing live DVR and we are not in the "live" point (most recent point) 
		 */		
		private var _inDvr:Boolean = false;
		
		/**
		 * workaround mainly for WV plugin, netstream reports end before it actually ended, so playbackComplete notification will be sent from the plugin 
		 */		
		public var ignorePlaybackComplete:Boolean;
		
		public var dvrWinSize:Number = 0;
		/**
		 * osmf sometimes sends duplicate errors, indicates that error wasn't sent for current media yet 
		 */		
		private var _mediaErrorSent:Boolean = false;
		
		private var _liveEventEnded:Boolean = false;
		
		private var _wasSeeking:Boolean = false;
		
		
		/**
		 * Constructor 
		 * @param name
		 * @param viewComponent
		 * 
		 */		
		public function KMediaPlayerMediator(name:String=null, viewComponent:Object=null)
		{
			name = name ? name : NAME;
			super(name, viewComponent);
		}
		
		/**
		 * Hadnler for the mediator registration; defines the _mediaProxy and _flashvars for the mediator.
		 * Also sets the bg color of the player, adds the event listeners for the events fired from the OSMF to be translated into notifications.
		 * and will listen to all the required events 
		 * 
		 */		
		override public function onRegister():void
		{	
			_mediaProxy = facade.retrieveProxy( MediaProxy.NAME ) as MediaProxy;
			_sequenceProxy = facade.retrieveProxy( SequenceProxy.NAME ) as SequenceProxy;
			var configProxy : ConfigProxy = facade.retrieveProxy( ConfigProxy.NAME ) as ConfigProxy;
			_flashvars = configProxy.vo.flashvars;
			
			
			//set autoPlay,loop,and autoRewind from flashvars
			
			//autoPlay Indicates whether the MediaPlayer starts playing the media as soon as its load operation has successfully completed.
			if(_flashvars.autoPlay == "true") _autoPlay = true;
			
			//loop Indicates whether the media should play again after playback has completed
			if(_flashvars.loop == "true") player.loop =  true;
			
			//autoRewind Indicates which frame of a video the MediaPlayer displays after playback completes. 
			if(_flashvars.autoRewind == "true") player.autoRewind =  true;
			else {
				player.autoRewind = false;
				
			}
			
			//if an autoMute flashvar passed as true mute the volume 
			if(_flashvars.autoMute == "true") _autoMute=true;
			
			//add all the event listeners needed from video component to make the KDP works
			player.addEventListener( DisplayObjectEvent.DISPLAY_OBJECT_CHANGE , onViewableChange );
			player.addEventListener( DisplayObjectEvent.MEDIA_SIZE_CHANGE , onMediaSizeChange );		
			
			player.addEventListener( MediaPlayerStateChangeEvent.MEDIA_PLAYER_STATE_CHANGE , onPlayerStateChange );
			
			player.addEventListener( TimeEvent.CURRENT_TIME_CHANGE , onPlayHeadChange , false, int.MAX_VALUE);
			player.addEventListener( AudioEvent.VOLUME_CHANGE , onVolumeChangeEvent );
			player.addEventListener( BufferEvent.BUFFER_TIME_CHANGE , onBufferTimeChange );
			player.addEventListener( BufferEvent.BUFFERING_CHANGE , onBufferingChange );
			
			player.addEventListener( LoadEvent.BYTES_TOTAL_CHANGE , onBytesTotalChange );
			player.addEventListener( LoadEvent.BYTES_LOADED_CHANGE , onBytesDownloadedChange );
			player.addEventListener( TimeEvent.DURATION_CHANGE , onDurationChange );
			player.addEventListener( DynamicStreamEvent.SWITCHING_CHANGE , onSwitchingChange );
			player.addEventListener( SeekEvent.SEEKING_CHANGE , onSeekingChange );
			player.addEventListener(AlternativeAudioEvent.NUM_ALTERNATIVE_AUDIO_STREAMS_CHANGE, onNumAlternativeAudioStreamsChange); 
			player.addEventListener(AlternativeAudioEvent.AUDIO_SWITCHING_CHANGE, onAlternateAudioSwitchingChange); 
			
			if(!_flashvars.disableOnScreenClick || _flashvars.disableOnScreenClick!="true")
			{
				var root:DisplayObject = (facade.retrieveMediator(RootMediator.NAME) as RootMediator).root;
				root.addEventListener( MouseEvent.CLICK , onMClick );
			} 

		}
		
		
		
		// Listen for a change in the number of alternative streams associated with this video. 
		private function onNumAlternativeAudioStreamsChange(event:AlternativeAudioEvent):void 
		{ 
			if (player.hasAlternativeAudio) 
			{ 
				trace("Number of alternative audio streams = ", player.numAlternativeAudioStreams); 
				var langs:Array = new Array();
				for ( var i:int = 0; i< player.numAlternativeAudioStreams; i++ ) {
					langs.push({ label: player.getAlternativeAudioItemAt(i).streamName, index: i } );
				}
					
				sendNotification( NotificationType.AUDIO_TRACKS_RECEIVED, { languages: langs} );
			} 
		} 
		
		// Listen for when an audio stream switch is in progress or has been completed. 
		private function onAlternateAudioSwitchingChange(event:AlternativeAudioEvent):void 
		{ 
			if ( !event.switching) {
				sendNotification( NotificationType.AUDIO_TRACK_SELECTED, {index : player.currentAlternativeAudioStreamIndex } );  
			} 			 
		} 
		
		
		/**
		 * Enables play/pause on clicking the video.
		 * 
		 */		
	/*	public function enableOnScreenClick(root:DisplayObject) : void
		{
			if(root && !player.hasEventListener(MouseEvent.CLICK))
				root.addEventListener( MouseEvent.CLICK , onMClick );
		}
		/**
		 * Disables play/pause on clicking the screen. 
		 * 
		 */		
		/*public function disableOnScreenClick() : void
		{
			if(player && player.hasEventListener(MouseEvent.CLICK))
				player.removeEventListener( MouseEvent.CLICK , onMClick );
		}*/
		/**
		 * Hnadler for on-screen click 
		 * @param event
		 * 
		 */		
		private function onMClick( event : MouseEvent ) : void 
		{
			if( player.canPlay && !player.playing )
				sendNotification(NotificationType.DO_PLAY);
			else if( player.canPause && player.playing) 
				sendNotification(NotificationType.DO_PAUSE);
		}
		
		/**
		 * List of the notifications that interest the player
		 * @return 
		 * 
		 */	    
		override public function listNotificationInterests():Array
		{
			return [
				NotificationType.SOURCE_READY,
				NotificationType.DO_PLAY,
				NotificationType.DO_STOP,
				NotificationType.CHANGE_MEDIA_PROCESS_STARTED,
				NotificationType.DO_PAUSE,
				NotificationType.DO_SEEK,
				NotificationType.DO_SWITCH,
				NotificationType.CLEAN_MEDIA,
				NotificationType.CHANGE_VOLUME,
				NotificationType.VOLUME_CHANGED_END,
				NotificationType.KDP_EMPTY,
				NotificationType.KDP_READY,
				LiveStreamCommand.LIVE_STREAM_READY,
				NotificationType.PLAYER_PLAYED,
				NotificationType.HAS_OPENED_FULL_SCREEN,
				NotificationType.HAS_CLOSED_FULL_SCREEN,
				NotificationType.CHANGE_PREFERRED_BITRATE,
				NotificationType.VIDEO_METADATA_RECEIVED,
				NotificationType.PLAYER_PLAY_END,
				NotificationType.MEDIA_ELEMENT_READY,
				NotificationType.GO_LIVE,
				NotificationType.MEDIA_LOADED,
				NotificationType.DO_AUDIO_SWITCH,
				NotificationType.LIVE_EVENT_ENDED
			];
		}
		
		/**
		 * Notification handler of the KMediaPlayerMediator
		 * @param note
		 * 
		 */		
		override public function handleNotification(note:INotification):void
		{ 
			switch(note.getName())
			{
				case NotificationType.SOURCE_READY: //when the source is ready for the media element
					cleanMedia(); //clean the media element if exist	
					setSource(); //set the source to the player
					break;
				
				case NotificationType.CHANGE_MEDIA_PROCESS_STARTED:
					//when we change the media we can reset the loadMediaOnPlay flag
					var designatedEntryId : String = String(note.getBody().entryUrl);
					_changeMediaOccur = true;
					_loadMediaOnPlay = false;
					player.removeEventListener( TimeEvent.COMPLETE , onTimeComplete );
					_isIntelliSeeking = false;
					_offsetAddition = 0;
					_doSwitchSent = false;
					_hasPlayed = false;
					ignorePlaybackComplete = false;
					_mediaErrorSent = false;
					dvrWinSize = 0;
					_liveEventEnded = false;
					_wasSeeking = false;
					entryDuration = _mediaProxy.vo.entryDuration;
					//Fixed weird issue, where the CHANGE_MEDIA would be caught by the mediator 
					// AFTER the new media has already loaded. Caused media never to be loaded.
					if (designatedEntryId != _mediaProxy.vo.entryUrl || _mediaProxy.vo.isFlavorSwitching )
					{
						cleanMedia();
					}
			
					break;
				case NotificationType.DO_PLAY: //when the player asked to play	
					//first, load the media, if we didn't load it yet
					if (_mediaProxy.shouldWaitForElement)
					{
						if (!_waitForMediaElement)
						{
							sendNotification(NotificationType.ENABLE_GUI, {guiEnabled : false , enableType : EnableType.CONTROLS});
							if ( _mediaProxy.vo.mediaPlayFrom != -1 && _mediaProxy.vo.deliveryType == StreamerType.HTTP ) {
								doIntelliSeek( _mediaProxy.vo.mediaPlayFrom );
								_mediaProxy.vo.mediaPlayFrom = -1;
							} else {
								_waitForMediaElement = true;
								_mediaProxy.prepareMediaElement();	
							}
							
						}	
					}
					else
					{
						onDoPlay();
					}
					
					break;
				
				case NotificationType.MEDIA_ELEMENT_READY:
					if (_waitForMediaElement)
					{
						_waitForMediaElement = false;	
						sendNotification(NotificationType.ENABLE_GUI, {guiEnabled : true , enableType : EnableType.CONTROLS});
						onDoPlay();
					}

					if (_mediaProxy.vo.isLive && _mediaProxy.vo.canSeek && _mediaProxy.vo.media)
					{
						_mediaProxy.vo.media.addEventListener(MediaElementEvent.TRAIT_ADD, onMediaTraitAdd);
						
					}
					_mediaProxy.vo.media.addEventListener(MediaElementEvent.TRAIT_ADD, onDynamicStreamTraitAdd);
					
					break;
				
				case LiveStreamCommand.LIVE_STREAM_READY: 
					//this means that this is a live stream and it is broadcasting now
					_mediaProxy.vo.isOffline = false;
					if ((_flashvars.autoPlay=="true" && !_hasPlayed) ||  _mediaProxy.vo.singleAutoPlay) {
						sendNotification(NotificationType.DO_PLAY);
						_mediaProxy.vo.singleAutoPlay = false;
					}
					break;
				case NotificationType.CLEAN_MEDIA:
					_mediaProxy.vo.media = null;
					//if we were explicitly asked to change media, first pause
					sendNotification(NotificationType.DO_PAUSE);
					cleanMedia();
				//	kMediaPlayer.hideThumbnail();
					//disable GUI (if its not already disabled)
					if (!_mediaProxy.vo.isMediaDisabled)
					{
						sendNotification( NotificationType.ENABLE_GUI , {guiEnabled : false , enableType : EnableType.CONTROLS} );
						_mediaProxy.vo.isMediaDisabled = true;
					}
					break;
				case NotificationType.DO_SWITCH:
					var flavorIndex:int = int(note.getBody().flavorIndex);
					
					//if we switch before the player is playing return
					if(player.state == MediaPlayerState.UNINITIALIZED)
					{
						//update preferred bitrate so the HD will be ready to play it...
						changePreferredBitrate(flavorIndex);	
						return;
					}
					
					if(player.isDynamicStream || _flashvars.forceDynamicStream) // rtmp adaptive mbr
					{
						//we need to set the mediaProxy prefered 
						
						//i have added it only here because it happen in CHANGE_MEDIA as well
						var dynamicStreamTrait : DynamicStreamTrait;
						if (player.media.hasTrait(MediaTraitType.DYNAMIC_STREAM))
						{
							dynamicStreamTrait = player.media.getTrait(MediaTraitType.DYNAMIC_STREAM) as DynamicStreamTrait;
						}
						if (dynamicStreamTrait && !dynamicStreamTrait.switching)
						{		
							if (flavorIndex == -1)
							{
								//If we switch to Auto Mode just enable it							
								KTrace.getInstance().log("Enable Auto Switch");
								_mediaProxy.vo.autoSwitchFlavors = player.autoDynamicStreamSwitch = true;
							}
							else 
							{
								KTrace.getInstance().log("Disable Auto Switch");
								_mediaProxy.vo.autoSwitchFlavors = player.autoDynamicStreamSwitch = false;
								
								if (flavorIndex != player.currentDynamicStreamIndex)
								{
									KTrace.getInstance().log("Requested stream index:", flavorIndex);
									KTrace.getInstance().log("Current stream index: ", player.currentDynamicStreamIndex);
									_doSwitchSent = true;
									player.switchDynamicStreamIndex(flavorIndex);
									
									sendNotification( NotificationType.SWITCHING_CHANGE_STARTED, {newIndex: flavorIndex} );
								}
							}
							
						}
					}
					else // change media
					{
						if (player.state == MediaPlayerState.PLAYING || player.state == MediaPlayerState.BUFFERING)
							_mediaProxy.vo.singleAutoPlay = true;
						_mediaProxy.vo.isFlavorSwitching = true;
					if (_mediaProxy.vo.keyframeValuesArray || isMP4Stream())
							_mediaProxy.vo.mediaPlayFrom = getCurrentTime();
						sendNotification( NotificationType.CHANGE_MEDIA, {entryUrl: _mediaProxy.vo.entryUrl} );
					}
					break;
					
				case NotificationType.DO_STOP: //when the player asked to stop
					sendNotification( NotificationType.DO_PAUSE );
					sendNotification( NotificationType.DO_SEEK , 0 );
					break;
				
				case NotificationType.DO_PAUSE: //when the player asked to pause
					_prevState = PAUSED;
					if (!_mediaProxy.vo.isFlavorSwitching)
						_mediaProxy.vo.singleAutoPlay = false;
					if(player && player.media && player.media.hasTrait(MediaTraitType.PLAY) )
					{
						if (player.canPause)
						{
							player.pause();
						}
						if (_mediaProxy.vo.isLive)
						{
							if ( !_liveEventEnded && ( !player.canPause || !player.canSeek) ) {
								player.stop();
								//to reload the media
								_mediaProxy.shouldWaitForElement = true;
							}
							//trigger liveStreamCommand to check for liveStream state again
							//if we are offline then the "live" check timer is already running
							sendNotification(NotificationType.LIVE_ENTRY, _mediaProxy.vo.resource); 
							if (player.canSeek)
								_inDvr = true;
						}
					}
					break;
				
				case NotificationType.DO_SEEK: //when the player asked to seek
					
					
					if ((player.state == MediaPlayerState.PLAYING || player.state == MediaPlayerState.BUFFERING) && getCurrentTime() < _duration)
					{
						_mediaProxy.vo.singleAutoPlay = true;
						_prevState = PLAYING;
					}
					else
					{
						_mediaProxy.vo.singleAutoPlay = false;
						_prevState = PAUSED;
					}
					
					var seekTo : Number = Number(note.getBody());
					if (!player.canSeek) 
					{
						//if doSeek was sent before first play, we should initiate the play
						if (!_hasPlayed && _mediaProxy.vo.mediaPlayFrom == -1)
						{
							_offset = seekTo;
							_isPrePlaySeek = true;
							_isPrePlaySeekInProgress = true;
							sendNotification(NotificationType.DO_PLAY);
						}
						return;
					}
					
					if(_mediaProxy.vo.deliveryType!=StreamerType.HTTP || 
						(_flashvars.ignoreStreamerTypeForSeek && _flashvars.ignoreStreamerTypeForSeek == "true"))
					{			
						if(player.canSeek) 
						{
							doSeek(seekTo);
						}
						return;	
					}
					
					if ((seekTo <= _loadedTime  && !_isIntelliSeeking))
					{
						if(player.canSeek) 
						{
							doSeek(seekTo);
						}
						
					}
					else {
						//do intlliseek 
						
						//cannot intelliseek in this case
						if((!_mediaProxy.vo.keyframeValuesArray && !isMP4Stream()) || !_hasPlayed) {
							sendNotification(NotificationType.PLAYER_SEEK_END);
						} else {
							//on a new seek we can reset the load media on play flag
							_loadMediaOnPlay = false;
							doIntelliSeek(seekTo);
						}
		
					}					
					break;
				
				case NotificationType.CHANGE_VOLUME:  //when the player asked to set new volume point
					player.volume = ( Number(note.getBody()) ); 
					break;
				
				case NotificationType.VOLUME_CHANGED_END: //change volume process ended, save to cookie if possible
					SharedObjectUtil.writeToCookie("KalturaVolume", "volume", player.volume, _flashvars.allowCookies);
					break;
				
				case NotificationType.KDP_EMPTY:
				case NotificationType.KDP_READY:
					
					if(_autoMute)
					{
						sendNotification(NotificationType.CHANGE_VOLUME, 0);	
					}
					break;
				
				case NotificationType.HAS_OPENED_FULL_SCREEN:
					if (_flashvars.maxAllowedFSBitrate && player.isDynamicStream) player.maxAllowedDynamicStreamIndex = findStreamByBitrate( _flashvars.maxAllowedFSBitrate );
					break;
				
				case NotificationType.HAS_CLOSED_FULL_SCREEN:
					if (_flashvars.maxAllowedRegularBitrate && player.isDynamicStream) player.maxAllowedDynamicStreamIndex = findStreamByBitrate( _flashvars.maxAllowedRegularBitrate );
					break;
				
				case NotificationType.VIDEO_METADATA_RECEIVED:
					//try to pre play seek only after we received video metadata and know if we can intelli seek
					if (!_sequenceProxy.vo.isInSequence &&_isPrePlaySeek)
					{
						//for rtmp the seek will be performed after player is in "playing" state
						if (_mediaProxy.vo.deliveryType == StreamerType.HTTP && (_mediaProxy.vo.keyframeValuesArray || isMP4Stream()))
						{
							doIntelliSeek(_offset);
						}		
						_isPrePlaySeek = false;
					}
					break;
				
				case NotificationType.CHANGE_PREFERRED_BITRATE:
					changePreferredBitrate(note.getBody().bitrateIndex);
					break;
				
				case NotificationType.PLAYER_PLAY_END:
					_offsetAddition = 0;
					break;
				
				case NotificationType.GO_LIVE:
					if ( _liveEventEnded ) {
						player.stop();
						//to reload the media
						_mediaProxy.shouldWaitForElement = true;
						
						sendNotification(NotificationType.DO_PLAY);
					}
					else if (_mediaProxy.vo.isLive && _mediaProxy.vo.canSeek)
					{
						if (_hasPlayed && _inDvr)
							sendNotification(NotificationType.DO_SEEK, player.duration);
						
						sendNotification(NotificationType.DO_PLAY);
					}
					break;
				case NotificationType.MEDIA_LOADED:
					//get embedded text, if exists
					var media : MediaElement = _mediaProxy.vo.media;
					while (media is ProxyElement)
					{
						media = (media as ProxyElement).proxiedElement;
					} 
					if (media.hasOwnProperty("client") && media["client"]) {
						media["client"].addHandler( "onTextData", onEmbeddedCaptions );
					}
					break;
				
				case NotificationType.DO_AUDIO_SWITCH:
					if (player.hasAlternativeAudio) 
					{    
						player.switchAlternativeAudioIndex(note.getBody().audioIndex); 
					}     
					break;
				
				case NotificationType.LIVE_EVENT_ENDED:
					_liveEventEnded = true;
					break;
			}
		}
		
		/**
		 * sets DVR window size according to actual window size (including Akamai's padding)
		 * @param e
		 * 
		 */		
		private function onMediaTraitAdd(e: MediaElementEvent) :  void
		{
			if (e.traitType==MediaTraitType.DVR)
			{
				var dvrTrait:DVRTrait = _mediaProxy.vo.media.getTrait(MediaTraitType.DVR) as DVRTrait;
				dvrWinSize = dvrTrait.windowDuration;
				_mediaProxy.vo.media.removeEventListener(MediaElementEvent.TRAIT_ADD, onMediaTraitAdd);
			}
			
		}

		private function onDynamicStreamTraitAdd(e: MediaElementEvent) :  void
		{
			if (e.traitType==MediaTraitType.DYNAMIC_STREAM)
			{
				var dynamicTrait:DynamicStreamTrait = _mediaProxy.vo.media.getTrait(MediaTraitType.DYNAMIC_STREAM) as DynamicStreamTrait;
				
				if (dynamicTrait.numDynamicStreams) 
				{
					var flvArray:Array = new Array();
					for (var i:int = 0; i<dynamicTrait.numDynamicStreams; i++)
					{
						var flavor:Object = {};
						flavor.type = "video/mp4";
						flavor.assetid = i;
						flavor.bandwidth = dynamicTrait.getBitrateForIndex(i) * 1024; 
						flavor.height = 0;
						flvArray.push(flavor);
					}
				
					sendNotification(NotificationType.FLAVORS_LIST_CHANGED, {flavors: flvArray});
					sendNotification( NotificationType.SWITCHING_CHANGE_COMPLETE, {newIndex : dynamicTrait.currentIndex , newBitrate: dynamicTrait.getBitrateForIndex( dynamicTrait.currentIndex )}  );	
					_mediaProxy.vo.media.removeEventListener(MediaElementEvent.TRAIT_ADD, onDynamicStreamTraitAdd);
					
					if (_flashvars.maxAllowedRegularBitrate) 
						player.maxAllowedDynamicStreamIndex = findStreamByBitrate( _flashvars.maxAllowedRegularBitrate );
				}
			}
			
		}
		
		private function onEmbeddedCaptions (info: Object)  : void {
			var proxyCaption:Object = new Object();
			proxyCaption.text = info.text;
			proxyCaption.trackid = info.trackid;
			proxyCaption.language = info.language;	

			sendNotification("loadEmbeddedCaptions", proxyCaption);
		}
		
		private function doSeek(seekTo:Number):void
		{
			
			if (_mediaProxy.vo.isLive)
			{
				if ( seekTo > player.duration ) {
					seekTo = player.duration;
				}
				
				if (seekTo==player.duration)
					_inDvr = false;
				else
					_inDvr = true;
			}
			player.seek(seekTo);
		}
		
		/**
		 * This function should be used to update the preferred bitrate. In order to affect the starting index of the video it should be called before the first play of the video.
		 * @param val
		 * 
		 */		
		private function changePreferredBitrate(curIndex:int):void 
		{
			if (curIndex > -1)
			{
				_mediaProxy.vo.selectedFlavorIndex = curIndex;
				if (!_mediaProxy.shouldWaitForElement)
					_mediaProxy.prepareMediaElement();		
			}
		}
		
		
		/**
		 * intelli seek to the given value
		 * set the given value as _offset 
		 * @param value
		 * 
		 */		
		private function doIntelliSeek(value:Number):void
		{	
			sendNotification(NotificationType.PLAYER_SEEK_START);
			_isAfterSeek = true;
			_isIntelliSeeking = true;
			_waitForMediaElement = true;
			_offset = value;
			_mediaProxy.prepareMediaElement( _offset );
			//_mediaProxy.loadWithMediaReady();
			 sendNotification( NotificationType.INTELLI_SEEK,{intelliseekTo: _offset} );
		}
		
		
		private function onDoPlay():void
		{		
			if (_mediaProxy.vo.isLive)
			{
				if (_mediaProxy.vo.isOffline)
				{
					return;
				}
			}
			
			if(!_sequenceProxy.vo.isInSequence && _mediaProxy.vo.entryUrl && 
				_sequenceProxy.hasSequenceToPlay() && !_isPrePlaySeekInProgress)
			{
				_sequenceProxy.vo.isInSequence = true;
				_sequenceProxy.playNextInSequence();
				return;
			}
			else if (!_mediaProxy.vo.media || player.media != _mediaProxy.vo.media)
			{
				if (_mediaProxy.vo.preferedFlavorBR && !isAkamaiHD())
				{
					_mediaProxy.vo.switchDue = true; //TODO: CHECK do we still need it?
				}
				_mediaProxy.loadWithMediaReady();
				return;
			}
			else if(player.canPlay) 
			{
				var timeTrait : TimeTrait = _mediaProxy.vo.media.getTrait(MediaTraitType.TIME) as TimeTrait;
				
				
				//if it's Entry and the entry id empty or equal -1 don't play
				if( !_mediaProxy.vo.entryUrl )
				{
					KTrace.getInstance().log("invalid entry URL", _mediaProxy.vo.entryUrl);
					return;
				} 
				
				if(!getCurrentTime() && _hasPlayed && !_isIntelliSeeking){
					sendNotification(NotificationType.DO_REPLAY);
					player.addEventListener(TimeEvent.COMPLETE, onTimeComplete);
					
				}
				
				//if we did intelligent seek and reach the end of the movie we must load the new url
				//back form 0 before we can play
				if(_loadMediaOnPlay)
				{
					_loadMediaOnPlay = false;
					_mediaProxy.prepareMediaElement();
					_mediaProxy.loadWithMediaReady();
					return;		
				}
				playContent();
			}
			else //not playable
			{
				_changeMediaOccur = false;
				player.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_PLAY_CHANGE,function(event:MediaPlayerCapabilityChangeEvent):void
				{
					if (!_changeMediaOccur && event.enabled)
					{
						sendNotification(NotificationType.DO_PLAY);
						_changeMediaOccur = true;
					}
				});
			}	
		}
		
		/**
		 * Get a reference to the OSMF player (inner event dispatcher of the KMediaPlayer)
		 * @return 
		 * 
		 */		
		public function get player():MediaPlayer
		{
			return (viewComponent as MediaPlayerSprite).mediaPlayer;	
		}
		
		public function get playerSprite():MediaPlayerSprite
		{
			return (viewComponent as MediaPlayerSprite);	
		}
		
		/**
		 * Play the media in the player. 
		 * 
		 */		
		public function playContent() : void
		{
			if (player.canPlay)
			{
				//fixes a bug with Wowza and live stream: resume doesn't work, we should re-load the media
				if ( _mediaProxy.vo.isLive
					&& (_flashvars.reloadOnPlayLS && _flashvars.reloadOnPlayLS == "true")
					&& _prevState == PAUSED
					&& !_reloadingLiveStream)
				{
					_reloadingLiveStream = true;
					_mediaProxy.prepareMediaElement();
					_mediaProxy.loadWithMediaReady();			
				}
				else
				{
					player.play();
				}
			}
		}
		
		/**
		 * Sets the  MediaElement of the player.
		 * 
		 */		
		public function setSource() : void
		{
			if(_mediaProxy.vo && _mediaProxy.vo.media)
			{
				player.media = _mediaProxy.vo.media; //set the current media to the player	
			}		
		}
		
		
		//private functions
		////////////////////////////////////////////
		
		/**
		 * describe the current state of the Media Player. 
		 * @param event
		 * 
		 */		
		private function onPlayerStateChange( event : MediaPlayerStateChangeEvent ) : void
		{	
			sendNotification( NotificationType.PLAYER_STATE_CHANGE , event.state );
			
			switch( event.state )
			{
				case MediaPlayerState.LOADING:
					
					// The following if-statement provides a work-around for using the mediaPlayFrom parameter for http-streaming content. Currently
					//  a bug exists in the Akamai Advanced Streaming plugin which prevents a more straight-forward implementation.
					if ( !_sequenceProxy.vo.isInSequence && isAkamaiHD())
					{
						
						if (_mediaProxy.vo.mediaPlayFrom)
						{
							player.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_SEEK_CHANGE, onCanSeekChange);
						}
						
					}
					break;
				case MediaPlayerState.READY: 
					if(! player.hasEventListener(TimeEvent.COMPLETE))
						player.addEventListener( TimeEvent.COMPLETE , onTimeComplete );
					
					if(!_playerReadyOrEmptyFlag)
					{
						_playerReadyOrEmptyFlag = true;
						var playerStatusProxy : PlayerStatusProxy = facade.retrieveProxy(PlayerStatusProxy.NAME) as PlayerStatusProxy;	
					}
					else
					{
						sendNotification( NotificationType.PLAYER_READY ); 
					}
					
					_mediaProxy.loadComplete();

					break;
				case MediaPlayerState.PAUSED:
					sendNotification( NotificationType.PLAYER_PAUSED );	
					break;
				
				case MediaPlayerState.PLAYING: 
					
					if(!_hasPlayed && !_sequenceProxy.vo.isInSequence){
						_hasPlayed = true;
					}
					
					if (player.media != null && !_sequenceProxy.vo.isInSequence)
					{	
						if (_mediaStartPlayFrom != -1)
						{
							if (canStartClip( _mediaStartPlayFrom )) 
							{
								if (isAkamaiHD())
								{
									setTimeout(seekToOffset, 1, _mediaStartPlayFrom);
								}
								else
								{
									player.seek(_mediaStartPlayFrom);
								}
								_mediaStartPlayFrom = -1;
							}
						}
						else if (_mediaProxy.vo.mediaPlayFrom != -1)
						{
							//special cases in plugins that handle the playback their own: hd akamai, uplynk
							if (!isAkamaiHD() && !(_mediaProxy.vo.deliveryType == StreamerType.HTTP && (isMP4Stream() || (_flashvars.ignoreStreamerTypeForSeek && _flashvars.ignoreStreamerTypeForSeek == "true"))))
							{
								if ( canStartClip( _mediaProxy.vo.mediaPlayFrom ) )
								{
									startClip();
									break;
								}
								//handle bug where the video metadata arrives after video starts to play
								else if (!_mediaProxy.vo.keyframeValuesArray && _mediaProxy.vo.deliveryType == StreamerType.HTTP)
								{
									_metadataTimer = new Timer(100);
									_metadataTimer.addEventListener(TimerEvent.TIMER, onMetadataTimer);
									_metadataTimer.start();
									break;
								}
							}
							else if (player.canSeek)
							{
								setTimeout(startClip, 1);
								break;
							}
						}
					}
					
					if(player.isDynamicStream && !_sequenceProxy.vo.isInSequence && !_doSwitchSent)
					{
						_mediaProxy.vo.autoSwitchFlavors = player.autoDynamicStreamSwitch = true;
					}
					
					KTrace.getInstance().log("current index:",player.currentDynamicStreamIndex);
					sendNotification( NotificationType.PLAYER_PLAYED );
					
					//the movie started, pre play seek has now ended (unless we are still waiting for videoMetadataRecieved)
					if (_isPrePlaySeekInProgress && !_isPrePlaySeek)
					{
						if (_mediaProxy.vo.deliveryType != StreamerType.HTTP && player.canSeek)
						{
							//fix a bug with akamai HD plugin, we can't call player.seek immediately
							if (isAkamaiHD())
								setTimeout(seekToOffset, 1, _offset);
								
							else
								player.seek(_offset);
							
							//in case we will have preroll this will save the starting point
							_mediaStartPlayFrom = _offset;
						}
						_isPrePlaySeekInProgress = false;
					}
					
					if (_reloadingLiveStream)
						_reloadingLiveStream = false;
					
					if(_isAfterSeek)
					{
						_isAfterSeek = false;
						sendNotification( NotificationType.PLAYER_UPDATE_PLAYHEAD , getCurrentTime() );
						sendNotification(NotificationType.PLAYER_SEEK_END);
						
					}
					break;
				case MediaPlayerState.PLAYBACK_ERROR:
					if (_flashvars.debugMode == "true")
					{
						KTrace.getInstance().log("KMediaPlayerMediator :: onPlayerStateChange >> osmf mediaplayer playback error.");
					}
					break;
			}
		}
		
		/**
		 * will call player.seek to  _mediaStartPlayFrom value
		 * Fixes a bug with seek and HDNetwork - we have to call seek with setTimout
		 * 
		 */		
		private function seekToOffset(value:Number):void {
			player.seek(value);
		}
		
		private function onMetadataTimer(event:TimerEvent):void {
			if (_mediaProxy.vo.keyframeValuesArray)
			{
				_metadataTimer.stop();
				_metadataTimer.removeEventListener(TimerEvent.TIMER, onMetadataTimer);
				startClip();
			}
		}
		
		
		private function canStartClip(startTime : Number) : Boolean
		{			
			if(_mediaProxy.vo.deliveryType!=StreamerType.HTTP)
			{
				
				if(player.canSeek)
				{
					return true;	
				}
			}
			
			
			if  (startTime <= _loadedTime  && !_isIntelliSeeking)
			{
				if(player.canSeek) 
				{
					return true;
				}
				
			}
			else //check if intelliseek is possible
			{		 
				if(_mediaProxy.vo.keyframeValuesArray || isMP4Stream())
				{
					return true;
				}
			}
			
			return false;
		}
		
		//////////////////////////////////////////////////////////
		/* The following block of code is a work-around for */
		/* using the mediaPlayFrom parameter for http-streaming
		* content. It will be removed when the Akamai Advanced
		* streaming plugin will be fixed to support this scenario.*/
		
		private function onCanSeekChange(event:MediaPlayerCapabilityChangeEvent):void
		{	
			//player.removeEventListener (MediaPlayerCapabilityChangeEvent.CAN_SEEK_CHANGE, onCanSeekChange);
			if (player.media != null && _mediaProxy.vo.mediaPlayFrom!=-1 && player.canSeek)
			{		
				if (isAkamaiHD())
				{
					
					setTimeout(startClip, 100 );
				}
			}
			
		}
		
		private function onDynamicStreamChange (e : MediaPlayerCapabilityChangeEvent): void
		{
			if(_mediaProxy.vo.switchDue && e.enabled)
			{
				_mediaProxy.vo.switchDue = false;
				sendNotification(NotificationType.DO_SWITCH, _mediaProxy.vo.preferedFlavorBR);
			}
		}
		
		private function startClip () : void
		{
			if (_mediaProxy.vo.mediaPlayFrom != -1)
			{
				var temp : Number = _mediaProxy.vo.mediaPlayFrom;
				_mediaProxy.vo.mediaPlayFrom = -1;
				sendNotification( NotificationType.DO_SEEK, temp );
				
			}
		}
		//////////////////////////////////////////////////////////////////////
		
		
		
		/**
		 * Dispatched when a MediaPlayer's ability to expose its media as a DisplayObject has changed
		 * @param event
		 * 
		 */		
		private function onViewableChange( event : DisplayObjectEvent ) : void
		{
			sendNotification( NotificationType.MEDIA_VIEWABLE_CHANGE );
		}
		
		/**
		 * dispatches when the player width and/or  height properties have changed. 
		 * @param event
		 * 
		 */		
		private function  onMediaSizeChange( event : DisplayObjectEvent ) :void
		{
			//deprecated
			//	if(_flashvars.sourceType==SourceType.URL)
			//		kMediaPlayer.setContentDimension(event.newWidth, event.newHeight);
			
		//	kMediaPlayer.validateNow();
		}
		
		/**
		 * A MediaPlayer dispatches this event when its playhead property has changed. 
		 * This value is updated at the interval set by the MediaPlayer's playheadUpdateInterval property.  
		 * @param event
		 * 
		 */		
		private function onPlayHeadChange( event : TimeEvent ) : void
		{
			//fix bug when after intelli-seek playhead jumps to a different point in the movie when playback ends
			if (_loadMediaOnPlay && !_sequenceProxy.vo.isInSequence)
				return;
			
			if (player.temporal && !isNaN(event.time))
			{
				var time:Number = _sequenceProxy.vo.isInSequence ? event.time : event.time + _offsetAddition;
				sendNotification( NotificationType.PLAYER_UPDATE_PLAYHEAD , time );
				
				
				if (_sequenceProxy.vo.isInSequence)
				{
					var duration : Number = (player.media.getTrait(MediaTraitType.TIME) as TimeTrait).duration;
					_sequenceProxy.vo.timeRemaining = (duration - time) > 0 ? Math.round(duration - event.time) : 0;	
					if (_sequenceProxy.vo.skipOffset)
					{
						_sequenceProxy.vo.skipOffsetRemaining = (_sequenceProxy.vo.skipOffset - time) > 0 ? Math.round(_sequenceProxy.vo.skipOffset - time) : 0;
						//reset skipoffset after offset time has passed
						if (!_sequenceProxy.vo.skipOffsetRemaining)
							_sequenceProxy.vo.skipOffset = 0;
					}

				}	
			}
		}
		
		
		/**
		 * A trait that implements the IAudible interface dispatches this event when its volume property has changed.  
		 * @param event
		 * 
		 */		
		private function onVolumeChangeEvent( event : AudioEvent ) : void
		{
			sendNotification( NotificationType.VOLUME_CHANGED , {newVolume:event.volume});
			if (event.volume==0 && _prevVolume!=0)
			{
				player.muted = true;
				sendNotification(NotificationType.MUTE);
			}
			else if (event.volume!=0 && _prevVolume==0)
			{
				player.muted = false;				
				sendNotification(NotificationType.UNMUTE);
			}
			
			_prevVolume = event.volume;
			
		}
		
		/**
		 * Dispatch the old time and the new time of the buffering 
		 * @param event
		 * 
		 */		
		private function onBufferTimeChange( event : BufferEvent ) : void
		{
			sendNotification( NotificationType.BUFFER_PROGRESS , {newTime:event.bufferTime} );
		}
		
		/**
		 * When the player start or stop the buffering 
		 * @param event
		 * 
		 */		
		private function onBufferingChange( event : BufferEvent ) : void
		{
			sendNotification( NotificationType.BUFFER_CHANGE , event.buffering );
		}
		/**
		 * The current and previous value of bytesDownloaded dispatches this event when bytes currently downloaded change 
		 * @param event
		 * 
		 */		
		private function onBytesDownloadedChange( event : LoadEvent ) : void
		{
			_bytesLoaded=event.bytes;
			_loadedTime=(_bytesLoaded/_bytesTotal)*_duration;
			sendNotification( NotificationType.BYTES_DOWNLOADED_CHANGE , {newValue:event.bytes} );
		}
		
		/**
		 * dispatched by a concrete implementation of IDownloadable when the value of the property "bytesTotal" has changed. 
		 * @param event
		 * 
		 */		
		private function onBytesTotalChange( event : LoadEvent ) : void
		{
			_bytesTotal=event.bytes;
			sendNotification( NotificationType.BYTES_TOTAL_CHANGE , {newValue:event.bytes} );
		}
		
		/**
		 * A trait that implements the ITemporal interface dispatches this event when its duration property has changed
		 * @param event
		 * 
		 */		
		private function onDurationChange( event : TimeEvent ) : void
		{
	
			//don't change duration on intelliseek, only if we are playing an ad
			if (_isIntelliSeeking)
			{
				if (_sequenceProxy.vo.isInSequence)
				{
					sendNotification( NotificationType.DURATION_CHANGE , {newValue:event.time});
				}
				else
				{
					
					sendNotification( NotificationType.DURATION_CHANGE , {newValue:entryDuration});
					if (isMP4Stream())
					{
						if (!isNaN(event.time) && event.time )
						{
							_offsetAddition = entryDuration - event.time ;
							sendNotification(NotificationType.RE_REGISTER_CUE_POINTS, {offsetAddition: _offsetAddition});
						}
						//mp4 intelliseek is probably not supported by cdn, and we got the movie from the beginning
						if (event.time == _duration) 
						{
							_isIntelliSeeking = false;
						}
					}
					
				}
			}
			else if(event.time)
			{
				_duration=event.time;
				sendNotification( NotificationType.DURATION_CHANGE , {newValue:_duration});
				//save entryDuration in case we will go into intelliseek and need to use it.
				if (!_sequenceProxy.vo.isInSequence)
					entryDuration = _duration;

			}		
		}
		
		/**
		 * Dispatched when the position  of a trait that implements the ITemporal interface first matches its duration. 
		 * @param event
		 * 
		 */		
		private function onTimeComplete( event : TimeEvent ) : void
		{
			if(event.type == TimeEvent.COMPLETE)
			{
				player.removeEventListener(TimeEvent.COMPLETE, onTimeComplete);
				if( _isIntelliSeeking && !_sequenceProxy.vo.isInSequence ){
					_isIntelliSeeking = false;
					_loadedTime=0;
					_loadMediaOnPlay = true;
				}	
				
				if (!_sequenceProxy.vo.isInSequence && _mediaProxy.vo.isLive)
				{
					if (player.canPause)
						player.pause();
					else
						player.stop();
					
					_inDvr = false;
				}
				
				if (!_mediaProxy.vo.isLive && (_sequenceProxy.vo.isInSequence || !ignorePlaybackComplete))
					sendNotification(NotificationType.PLAYBACK_COMPLETE, {context: _sequenceProxy.sequenceContext});
			}
			
		}

		
		/**
		 * 
		 * @param event
		 * 
		 */		
		private function onSwitchingChange( event : DynamicStreamEvent ) : void
		{
			KTrace.getInstance().log("DynamicStreamEvent ===> " , event.type , player.currentDynamicStreamIndex);
			
			if (!event.switching)
			{
				sendNotification( NotificationType.SWITCHING_CHANGE_COMPLETE, {newIndex : player.currentDynamicStreamIndex, newBitrate: player.getBitrateForDynamicStreamIndex(player.currentDynamicStreamIndex)}  );
			}
			else if (player.autoDynamicStreamSwitch)
			{
				sendNotification( NotificationType.SWITCHING_CHANGE_STARTED, {currentIndex : player.currentDynamicStreamIndex, currentBitrate: player.getBitrateForDynamicStreamIndex(player.currentDynamicStreamIndex)});
			}
		}
		
		private function onSeekingChange( event: SeekEvent ) : void 
		{
			if ( event.seeking ) {
				_wasSeeking = true;
				sendNotification(NotificationType.PLAYER_SEEK_START);
			} else if ( _wasSeeking ) {
				_wasSeeking = false;
				sendNotification( NotificationType.PLAYER_UPDATE_PLAYHEAD , getCurrentTime() );
				sendNotification(NotificationType.PLAYER_SEEK_END);
			}
		}
		
		/**
		 * Function which removed the current media element from the 
		 * OSMF media player.
		 * 
		 */		
		public function cleanMedia():void
		{
			//we don't need to clean the media if it's empty	
			if(!player.media) return;
			
			if (player.media.hasOwnProperty("cleanMedia") || (player.state == MediaPlayerState.PLAYING && !_isIntelliSeeking))
				sendNotification( NotificationType.DO_STOP );
			
			if(player.displayObject)
			{
				player.displayObject.height=0;////this is for clear the former clip...
				player.displayObject.width=0;///this is for clear the former clip...
			}
			
			
			player.media = null;
			
		}
		
		
		
		public function get isIntelliSeeking():Boolean
		{
			return _isIntelliSeeking;
		}
		
		/**
		 * set b64Referrer and save it to flashvars 
		 * 
		 */		
		private function setB64Referrer():void
		{
			if (_flashvars.referrer)
			{
				var b64 : Base64Encoder = new Base64Encoder();
				b64.encode( _flashvars.referrer );
				_flashvars.b64Referrer = b64.toString();	
			}
		}
		
		/**
		 * 
		 * @return true if the current playing stream is MP4
		 * 
		 */		
		private function isMP4Stream():Boolean {
			return ( _mediaProxy.vo.isMp4 );
			/*if (_mediaProxy.vo.kalturaMediaFlavorArray)
			{
				if (_mediaProxy.vo.selectedFlavorId)
				{
					for each (var flavor:KalturaFlavorAsset in _mediaProxy.vo.kalturaMediaFlavorArray)
					{
						if (flavor.id==_mediaProxy.vo.selectedFlavorId)
						{
							if (flavor.fileExt=="mp4")
								return true;
							
							return false;
						}
					}	
				}
				//if we don't have selected flavor ID we are playing the first one
				else if (_mediaProxy.vo.kalturaMediaFlavorArray.length)
				{
					if ((_mediaProxy.vo.kalturaMediaFlavorArray[0] as KalturaFlavorAsset).fileExt=="mp4")
						return true;
				}
			}
			
			return false;*/
		}
		
		private function isAkamaiHD():Boolean
		{
			return (_mediaProxy.vo.deliveryType == StreamerType.HDNETWORK || _mediaProxy.vo.deliveryType == StreamerType.HDNETWORK_HDS);
		}
		
		/**
		 *  
		 * @return player.currentTime + offset in case mp4 intelliseek was performed 
		 * 
		 */		
		public function getCurrentTime():Number
		{
			return _sequenceProxy.vo.isInSequence ? player.currentTime : player.currentTime + _offsetAddition;
		}
		
		/**
		 * This function searches for the flavor with the preferedBitrate value bitrate among the flavors belonging to the media.
		 * @param preferedBitrate The value of the prefered bitrate to search for among the stream items of the media.
		 * @return The function returns the index of the streamItem with the prefered bitrate
		 * 
		 */		
		public function findStreamByBitrate (preferedBitrate : int) : int
		{
			var foundStreamIndex:int = -1;
			
			if (player.numDynamicStreams > 0)
			{
				for(var i:int = 0; i < player.numDynamicStreams; i++)
				{
					var lastb:Number;
					if(i!=0)
						lastb = player.getBitrateForDynamicStreamIndex(i-1);
					
					var b:Number = player.getBitrateForDynamicStreamIndex(i);
					b = Math.round(b/100) * 100;
					
					if (b == preferedBitrate)
					{
						//if we found it set it and leave
						foundStreamIndex = i;
						return foundStreamIndex;
					}
					else if(i == 0 && preferedBitrate < b)
					{
						//if the first is bigger then the prefered bitrate set it and leave
						foundStreamIndex = i;
						return foundStreamIndex;
					}
					else if( lastb && preferedBitrate < b  && preferedBitrate > lastb )
					{
						//if the prefered bit rate is between the last index and the current choose the closer one
						var topDelta : int = b - preferedBitrate;
						var bottomDelta : int = preferedBitrate - lastb;
						if(topDelta<=bottomDelta)
						{
							foundStreamIndex = i;
							return foundStreamIndex;
						}
						else
						{
							foundStreamIndex = i-1;
							return foundStreamIndex;
						}
					}
					else if(i == player.numDynamicStreams-1 && preferedBitrate >= b)
					{
						//if this is the last index and the prefered bitrate is still bigger then the last one
						foundStreamIndex = i;
						return foundStreamIndex;
					}
				}
			}
			
			return foundStreamIndex;
		}
		
	}
}