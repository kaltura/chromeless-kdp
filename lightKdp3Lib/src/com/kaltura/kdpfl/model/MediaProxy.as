package com.kaltura.kdpfl.model
{
	import com.kaltura.kdpfl.model.strings.MessageStrings;
	import com.kaltura.kdpfl.model.type.EnableType;
	import com.kaltura.kdpfl.model.type.NotificationType;
	import com.kaltura.kdpfl.model.type.SourceType;
	import com.kaltura.kdpfl.model.type.StreamerType;
	import com.kaltura.kdpfl.model.vo.MediaVO;
	import com.kaltura.kdpfl.model.vo.SequenceVO;
	import com.kaltura.kdpfl.util.URLUtils;
	import com.kaltura.kdpfl.view.controls.KTrace;
	import com.kaltura.kdpfl.view.media.KMediaPlayerMediator;
	import com.kaltura.osmf.buffering.DualThresholdBufferingProxyElement;
	import com.kaltura.osmf.events.KSwitchingProxyEvent;
	import com.kaltura.osmf.events.KSwitchingProxySwitchContext;
	import com.kaltura.osmf.proxy.KSwitchingProxyElement;
	
	import flash.events.Event;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	
	import org.osmf.elements.F4MElement;
	import org.osmf.elements.F4MLoader;
	import org.osmf.elements.ProxyElement;
	import org.osmf.elements.VideoElement;
	import org.osmf.events.MediaErrorCodes;
	import org.osmf.events.MediaErrorEvent;
	import org.osmf.media.MediaElement;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.media.URLResource;
	import org.osmf.metadata.Metadata;
	import org.osmf.metadata.MetadataNamespaces;
	import org.osmf.net.DynamicStreamingResource;
	import org.osmf.net.NetStreamCodes;
	import org.osmf.net.StreamType;
	import org.osmf.net.StreamingURLResource;
	import org.puremvc.as3.patterns.proxy.Proxy;
    import org.osmf.layout.LayoutMetadata;
    import org.osmf.layout.HorizontalAlign;
    import org.osmf.layout.VerticalAlign;
    import org.osmf.layout.ScaleMode;
    import org.osmf.layout.LayoutMode;
    
	/**
	 * This class is the proxy for the media playing in the media player.
	 * 
	 */	
	public class MediaProxy extends Proxy
	{
		public static const NAME:String = "mediaProxy";
		
		/**
		 * represents the starting bitrate index, if exists
		 */		
		public var startingIndex:int;
		
		public var shouldCreateSwitchingProxy : Boolean = true;
		
		private var _sendMediaReady : Boolean;
		private var _flashvars : Object;
		private var _isElementLoaded : Boolean;
		/**
		 * indicates if this is a new media and we should wait for mediaElementReady notification
		 */		
		public var shouldWaitForElement:Boolean;
		
		private var _resource:URLResource;
		
		namespace xmlns = "http://ns.adobe.com/f4m/1.0";
		
		/**
		 *Constructor 
		 * @param data - value object of the Proxy.
		 * 
		 */		
		public function MediaProxy( data:Object=null )
		{
			super( NAME, new MediaVO()  );
			_flashvars = (facade.retrieveProxy( ConfigProxy.NAME ) as ConfigProxy).vo.flashvars;
			
		}
		/**
		 * Function prepares a new media element according to the information from the kaltura MediaEntry
		 * @param seekFrom - optional parameter, passed if the video being loaded is a response to intelligent seeking.
		 * 
		 */		
		public function prepareMediaElement(seekFrom :uint = 0) : void
		{
			var entryUrl:String = vo.entryUrl;
			var resource:MediaResourceBase;
			//support intelli-seek if playmanifest url
			if ( seekFrom != 0 && vo.entryUrl.indexOf("playManifest")!=-1 ) {
				var index:int = vo.entryUrl.lastIndexOf('/a/a.');
				if ( index > 0 ) {
					entryUrl = vo.entryUrl.substring(0, index) + '/seekFrom/' + seekFrom * 1000 + vo.entryUrl.substring(index) ;
				}				
			}
			
			switch (vo.deliveryType)
			{
				case StreamerType.LIVE:
					
					//Create resource for live streaming entry
				//	var liveStreamUrl : String = vo.entryUrl;
				//	resource = new StreamingURLResource(liveStreamUrl, StreamType.LIVE);
					createElement(entryUrl, StreamType.LIVE);
					
					break;
				
				case StreamerType.RTMP:	
					var streamFormat : String = _flashvars.streamFormat ? (_flashvars.streamFormat + ":") : "";
					var rtmpUrl:String = entryUrl;
					if (!URLUtils.getProtocol(rtmpUrl)) // if we didn't get a full url, we build it
					{
						rtmpUrl = _flashvars.streamerUrl + "/" + streamFormat + rtmpUrl;
					}
					createElement(rtmpUrl);
					
					break;
				case StreamerType.HLS:
				case StreamerType.HTTP:
				case StreamerType.HDNETWORK:
				case StreamerType.HDNETWORK_HDS:
				case StreamerType.HDS:
					if ( vo.sourceType != SourceType.URL && vo.isTwoPhaseManifest )
					{
						var urlLoader:URLLoader = new URLLoader();
						urlLoader.addEventListener(Event.COMPLETE, onUrlComplete);
						urlLoader.load(new URLRequest(entryUrl));
					}
					else
						createElement(entryUrl); 
					break;
			}
		}

		
		/**
		 * creates the proper media element according to the given resourceUrl 
		 * @param resourceUrl
		 * 
		 */		
		private function createElement(resourceUrl:String, streamType:String = null):void {
			var resource:MediaResourceBase;
			var endIndex:int = resourceUrl.indexOf("?");
			if ( endIndex == -1 )
				endIndex = resourceUrl.length;
			var postfix:String = resourceUrl.substring(endIndex-4, endIndex);
			//url resource
			if (vo.sourceType == SourceType.URL || postfix!=".f4m" || vo.deliveryType == StreamerType.HDNETWORK || vo.isTwoPhaseManifest || vo.isHds || vo.deliveryType == StreamerType.HLS )
			{
				resource = new StreamingURLResource(resourceUrl, StreamType.LIVE_OR_RECORDED);
				addMetadataToResource(resource);
				var element:MediaElement = vo.mediaFactory.createMediaElement(resource);
				var adaptedHDElement : DualThresholdBufferingProxyElement = new DualThresholdBufferingProxyElement( vo.initialBufferTime, vo.expandedBufferTime, element);
				vo.media = adaptedHDElement;			
			}			
			else //f4m resource
			{	
				resource = new StreamingURLResource(resourceUrl, streamType);
				addMetadataToResource(resource);
				var f4mLoader : F4MLoader = new F4MLoader(vo.mediaFactory);
				//to set initial flavor we should disable auto switch, we return it after first play
				(facade.retrieveMediator(KMediaPlayerMediator.NAME) as KMediaPlayerMediator).player.autoDynamicStreamSwitch = false;
				if (vo.selectedFlavorIndex !=-1)
				{
					resource.addMetadataValue(MetadataNamespaces.RESOURCE_INITIAL_INDEX, vo.selectedFlavorIndex);
					startingIndex = vo.selectedFlavorIndex;
				}
				f4mLoader.useRtmptFallbacks = _flashvars.useRtmptFallback == "false" ? false : true;				
				var f4mElem : F4MElement = new F4MElement (resource as URLResource, f4mLoader) ;
				
				var adaptedElement : DualThresholdBufferingProxyElement = new DualThresholdBufferingProxyElement((vo.isLive ? vo.initialLiveBufferTime : vo.initialBufferTime), (vo.isLive ? vo.expandedLiveBufferTime : vo.expandedBufferTime), f4mElem);
				vo.media = adaptedElement;				
			}
			
			saveResourceAndMedia(resource);
		}
		
		
		/**
		 * parses metadata from flashvars and add it to the given resource 
		 * relevant flashvars: metadataNamespace[i] = String, the namespace of the metadata
    	 * metadataValues[i] = String, The metadata to set. The syntax of this flashvar is comma seperated key=value strings. each key=value string represents a new metadata value.
    	 * for example: first=one,second=two,third=three
		 * 
		 */		
		private function addMetadataToResource(resource:MediaResourceBase):void
		{
			var i:int = 0;
			while (_flashvars.hasOwnProperty("metadataNamespace" + i) && _flashvars.hasOwnProperty("metadataValues" + i))
			{
				var metadata:Metadata = resource.getMetadataValue(_flashvars["metadataNamespace" + i]) as Metadata;	
				// if not created a new metadata object is created
				if (metadata == null)
				{
					metadata = new Metadata();
				}
				var valsArray:Array = (_flashvars["metadataValues" + i] as String).split(",");
				for (var k:int = 0; k<valsArray.length; k++)
				{
					var cur:String = valsArray[k];
					var index:int = cur.indexOf("=");
					if (index!=-1)
					{
						metadata.addValue(cur.substr(0, index), cur.substring(index+1) );
					}
				}
				resource.addMetadataValue(_flashvars["metadataNamespace" + i], metadata);
				i++;
			}
			
			//in case metadata values are represented as objects, they will be handled in this function
			addObjectMetadataToResource(resource);
		}
		
		/**
		 * parses resources metadata from flashvars and add the metadata on the given resource. Support JSON rperesentations for the metadata values 
		 * relevant flashvars: objMetadataNamespace[i] = String, the namespace of the metadata
    	 * objMetadataValues[i] = String, The metadata to set. The syntax of this flashvar is "&" seperated key=value strings. each key=value string represents a new metadata value.
    	 * for example: first=one&second=two&third=three
		 * metadata value can be a json object, for example: first={one:1,two:2}&second=bla
		 * 
		 */		
		private function addObjectMetadataToResource(resource:MediaResourceBase):void
		{
			var i:int = 0;
			while (_flashvars.hasOwnProperty("objMetadataNamespace" + i) && _flashvars.hasOwnProperty("objMetadataValues" + i))
			{
				var metadata:Metadata = resource.getMetadataValue(_flashvars["objMetadataNamespace" + i]) as Metadata;	
				// if not created a new metadata object is created
				if (metadata == null)
				{
					metadata = new Metadata();
				}
				var valsArray:Array = (_flashvars["objMetadataValues" + i] as String).split("&");
				for (var k:int = 0; k<valsArray.length; k++)
				{
					var cur:String = valsArray[k];
					var index:int = cur.indexOf("=");
					if (index!=-1)
					{
						var val:String = cur.substring(index+1);
						var valAsObj:Object = val;
						if (val.charAt(0)=="{" && val.charAt(val.length-1)=="}")
						{
							//array of all object properties
							var propsArr:Array = val.substr(1, val.length - 2).split(",");
							valAsObj = new Object();
							for (var j:int=0; j<propsArr.length; j++)
							{
								var property:String = propsArr[j];
								var ind:int = property.indexOf(":");
								var objKey:String = property.substr(0, ind);
								var objVal:String = property.substring(ind + 1, val.length);	
								//convert value to boolean or number or string
								valAsObj[objKey] = getValueObject(objVal);
							}
						}
						else
						{
							valAsObj = getValueObject(val);
						}

						metadata.addValue(cur.substr(0, index), valAsObj );
					}
				}
				resource.addMetadataValue(_flashvars["objMetadataNamespace" + i], metadata);
				i++;
			}
			
		}
		
		/**
		 * converts given object to boolean / number / object 
		 * @param val
		 * @return 
		 * 
		 */		
		private function getValueObject(val:String):Object
		{
			var valAsNum:Number = valAsNum = parseFloat(val);
			var valAsObj:Object = val=="true"? true: val=="false" ? false : isNaN(valAsNum) ? val : valAsNum;
			return valAsObj;
		}
		
		/**
		 * Getter for the MediaProxy data.
		 * @return returns the MediaVO of the MediaProxy.
		 * 
		 */		
		public function get vo():MediaVO  
		{  
			return data as MediaVO;  
		} 
		/**
		 * Setter for the proxy data.
		 * @param mediaVO new data to place in the MediaVO.
		 * 
		 */        
		public function set vo (mediaVO : MediaVO) : void
		{
			data = mediaVO;
		}
		/**
		 * Getter for the VideoElement of the media.
		 * @return VideoElement
		 * 
		 */        
		public function get videoElement () : VideoElement
		{
			var media : MediaElement = vo.media;
			
			while (media is ProxyElement)
			{
				media = (media as ProxyElement).proxiedElement;
			} 
			//In order to enable Intelligent Seeking in the video, we need to receive the key-frame array from the MetaData.
			if(media is VideoElement)
			{
				return media as VideoElement;
			}
			return null;
		}
		
		
		public function set videoElement (newElem : VideoElement) : void
		{
			var media : MediaElement = vo.media;
			
			while (media is ProxyElement)
			{
				media = (media as ProxyElement).proxiedElement;
			} 
			//In order to enable Intelligent Seeking in the video, we need to receive the key-frame array from the MetaData.
			if(media is VideoElement)
			{
				media = newElem;
			}
			
		}
		
		/**
		 * Getter for the MediaElement of the media.
		 * @return VideoElement
		 * 
		 */        
		public function get mediaElement () : MediaElement
		{
			var media : MediaElement = vo.media;
			
			while (media is ProxyElement)
			{
				media = (media as ProxyElement).proxiedElement;
			} 
			
			return media;
		}
		
		/**
		 * Function initiates the load of the video file that belongs to the Media Element,
		 * and indicates that a MEDIA_READY notification should be sent when the process is complete.
		 * 
		 */        
		public function loadWithMediaReady () : void
		{
			if (vo.media)
			{
				_isElementLoaded = false;
				vo.media.addEventListener(MediaErrorEvent.MEDIA_ERROR, onError);
				_sendMediaReady = true;
				
				sendNotification(NotificationType.SOURCE_READY);
			}
			
		}
		
		/**
		 * Function initates the load of the video file that belongs to the Media Element 
		 * and indicates that there is no need to send the MEDIA_READY notification when the process is complete.
		 * @param doPlay - flag signifying whether the video should begin playing on being loaded.
		 * 
		 */        
		public function loadWithoutMediaReady (doPlay : Boolean = false) : void
		{
			_isElementLoaded = false;
			vo.media.addEventListener(MediaErrorEvent.MEDIA_ERROR, onError);
			vo.playOnLoad = doPlay;
			_sendMediaReady = false;
			sendNotification(NotificationType.SOURCE_READY);
		}
		/**
		 * Function that handles the complete load of the video file that belongs to the media element.
		 * 
		 */        
		public function loadComplete() : void
		{
			if(!_isElementLoaded)
			{
				
				_isElementLoaded = true;
				if (mediaElement)
				{
					if (mediaElement.hasOwnProperty("smoothing"))
						mediaElement["smoothing"] = true;
					if (mediaElement.hasOwnProperty("client") && mediaElement["client"])
						mediaElement["client"].addHandler(NetStreamCodes.ON_META_DATA, onMetadata);
                    
                    if ( _flashvars.stretchVideo ) {
                        var layout:LayoutMetadata = new LayoutMetadata();
                        layout.percentWidth  = 100;
                        layout.percentHeight = 100;
                        layout.layoutMode = LayoutMode.HORIZONTAL;
                        layout.horizontalAlign = HorizontalAlign.CENTER;
                        layout.verticalAlign = VerticalAlign.TOP;
                        layout.scaleMode = ScaleMode.STRETCH;
                        
                        mediaElement.removeMetadata(LayoutMetadata.LAYOUT_NAMESPACE);
                        mediaElement.addMetadata(LayoutMetadata.LAYOUT_NAMESPACE, layout);
                    }
				}
				if (_sendMediaReady)
				{
					sendNotification(NotificationType.MEDIA_LOADED);	
				}
				else
				{
					if (vo.playOnLoad)
					{
						vo.playOnLoad = false;
						sendNotification(NotificationType.DO_PLAY);
					}
				}
			}
		}
		
		/**
		 * Function stores the array of key frames from the media meta data on the MediaVO.
		 * @param info the Meta Data for the kaltura media.
		 * 
		 */       
		private function onMetadata(info:Object):void// reads metadata..
		{
			vo.keyframeValuesArray=info.times; 
			sendNotification(NotificationType.VIDEO_METADATA_RECEIVED, {keyframeValuesArray: vo.keyframeValuesArray, info: info});
		}
		
		/**
		 * 
		 * @param evt
		 * 
		 */	   
		private function onError(evt:MediaErrorEvent):void
		{
			KTrace.getInstance().log("media error", evt.error ? evt.error.errorID: '', evt.error ? evt.error.detail: '');
			
			if(evt.type==MediaErrorEvent.MEDIA_ERROR)
			{
				if (evt.error && (evt.error.errorID == MediaErrorCodes.NETSTREAM_PLAY_FAILED)) 
				{
					KTrace.getInstance().log("media error", evt.error.errorID, evt.error.detail);
				}
				else 
				{
					sendNotification(NotificationType.MEDIA_ERROR , {errorEvent : evt});
					sendNotification(NotificationType.DO_STOP);
					sendNotification(NotificationType.ALERT,{message:MessageStrings.getString('CLIP_NOT_FOUND'),title:MessageStrings.getString('CLIP_NOT_FOUND_TITLE')})
				}
			}
		}
		
		protected function onSwitchPerformed (e : KSwitchingProxyEvent) : void
		{
			var sequenceProxy : SequenceProxy = facade.retrieveProxy(SequenceProxy.NAME) as SequenceProxy;
			var curContext:String;
			if (e.switchingProxySwitchContext == KSwitchingProxySwitchContext.SECONDARY)
			{
				sequenceProxy.vo.isInSequence = true;
				sequenceProxy.vo.isAdSkip = true;
				//we will replace to secondary, current is main
				curContext = KSwitchingProxySwitchContext.MAIN;
			}
			else
			{
				sequenceProxy.vo.isInSequence = false;
				sequenceProxy.vo.isAdSkip = false;
				curContext = KSwitchingProxySwitchContext.SECONDARY;
			}
			sendNotification(NotificationType.SWITCHING_MEDIA_ELEMENTS_STARTED, {currentContext: curContext});
		}
		
		protected function onSwitchCompleted (e: KSwitchingProxyEvent) : void 
		{
			sendNotification(NotificationType.SWITCHING_MEDIA_ELEMENTS_COMPLETED, {currentContext: e.switchingProxySwitchContext});
		}
		
		protected function onSwitchFailed (e: KSwitchingProxyEvent) : void 
		{
			sendNotification(NotificationType.SWITCHING_MEDIA_ELEMENTS_FAILED);
		}

		/**
		 * Set the starting index and notify KFlavorComboBox on the new index 
		 * @param index
		 * 
		 */		
		public function notifyStartingIndexChanged(index:int):void 
		{
			startingIndex = index;
			//to display correct value in KFlavorComboBox
			sendNotification( NotificationType.SWITCHING_CHANGE_COMPLETE, {newIndex : index}  );	
		}
		
		
		/**
		 * This is used when playing HDS content. We will parse the URL we get from the server and play it. 
		 * @param event
		 * 
		 */		
		private function onUrlComplete(event: Event): void
		{
			(event.target as URLLoader).removeEventListener(Event.COMPLETE, onUrlComplete);
			
			var manifest : XML = new XML((event.target as URLLoader).data);
			var children : XMLList = manifest.xmlns::media;
			var _resourceUrl:String = children[0].@url;
			
			createElement(_resourceUrl);
		}
		
		
		
		/**
		 * Function to determine whether the player is in autoPlay mode and should load and play the entry's video element
		 * or hold off.
		 * 
		 */		
		public function configurePlayback () : void
		{	
			var sequenceProxy : SequenceProxy = facade.retrieveProxy(SequenceProxy.NAME) as SequenceProxy;
			
			if (!vo.isMediaDisabled)
			{
				if (vo.isLive)
				{
					if (!vo.isHds)
						prepareMediaElement();
					//sendNotification(NotificationType.ENABLE_GUI, {guiEnabled : false , enableType : EnableType.CONTROLS});
					sendNotification(NotificationType.LIVE_ENTRY, vo.resource);
				}
			}
			
			if ((_flashvars.autoPlay == "true" || vo.singleAutoPlay) && !vo.isMediaDisabled && (! sequenceProxy.vo.isInSequence))
			{
				if (vo.singleAutoPlay)
					vo.singleAutoPlay = false;
				sendNotification(NotificationType.DO_PLAY);
			}
			
		}
		
		/**
		 * This function ends the prepareMediaElement flow. Will save resource to mediaVo, create proper media elemenet and dispatch media ready if needed. 
		 * @return 
		 * 
		 */		
		private function saveResourceAndMedia(resource:MediaResourceBase) : void
		{
			vo.resource = resource;
			
			if (shouldCreateSwitchingProxy)
			{
				//wrap the media element created above in a KSwitcingProxy in order to enable midrolls.
				var switchingMediaElement : KSwitchingProxyElement = new KSwitchingProxyElement();
				switchingMediaElement.mainMediaElement = vo.media;
				//set the KSwitcingProxyElement as the vo.media
				vo.media = switchingMediaElement;
				//if its a new media and not a bumper entry
				var sequenceVo:SequenceVO = (facade.retrieveProxy(SequenceProxy.NAME) as SequenceProxy).vo;
				if (!sequenceVo.isInSequence)
					sequenceVo.mainMediaVO = null;
				//add event listener for a switch between the main and secondary elements in the KSwitcingProxyElement.
				vo.media.addEventListener(KSwitchingProxyEvent.ELEMENT_SWITCH_PERFORMED, onSwitchPerformed );
				vo.media.addEventListener(KSwitchingProxyEvent.ELEMENT_SWITCH_COMPLETED, onSwitchCompleted );
				vo.media.addEventListener(KSwitchingProxyEvent.ELEMENT_SWITCH_FAILED, onSwitchFailed );
				
				
			}
			
			if (shouldWaitForElement)
				shouldWaitForElement = false;
			
			sendNotification(NotificationType.MEDIA_ELEMENT_READY);
		}
		
	}
	
}