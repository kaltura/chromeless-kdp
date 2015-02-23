package com.kaltura.kdpfl.plugin
{
	import com.kaltura.kdpfl.model.MediaProxy;
	import com.kaltura.kdpfl.model.type.NotificationType;
	import com.kaltura.kdpfl.view.media.KMediaPlayerMediator;
	import com.kaltura.osmf.proxy.KSwitchingProxyElement;
	
	import flash.events.Event;
	
	import org.osmf.elements.SWFElement;
	import org.osmf.elements.SWFLoader;
	import org.osmf.media.MediaPlayer;
	import org.osmf.media.URLResource;
	import org.osmf.vpaid.elements.VPAIDElement;
	import org.osmf.vpaid.metadata.VPAIDMetadata;
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.mediator.Mediator;
	
	public class VPaidPluginMediator extends Mediator
	{
		public static const NAME:String = "VPaidPluginMediator";
		
		private var _eventsList:Array = ["AdLoaded","AdStarted","AdStopped","AdSkipped","AdSkippableStateChange","AdSizeChange","AdLinearChange","AdDurationChange","AdExpandedChange"," AdRemainingTimeChange","AdVolumeChange","AdImpression","AdVideoStart","AdVideoFirstQuartile","AdVideoMidpoint","AdVideoThirdQuartile","AdVideoComplete","AdClickThru","AdInteraction","AdUserAcceptInvitation","AdUserMinimize","AdUserClose","AdPaused","AdPlaying","AdLog","AdError"];
				
		private var _mediaProxy:MediaProxy;
		private var _vpaid:VPAIDElement;
		private var _adParameters:String;
		private var _adDimensions:Object;
		
		public function VPaidPluginMediator(adParameters:String, adDimensions:Object, mediatorName:String=null, viewComponent:Object=null)
		{
			_adParameters = adParameters;
			_adDimensions = adDimensions;
			super(NAME, viewComponent);
		}
		
		override public function onRegister():void {
			_mediaProxy = facade.retrieveProxy(MediaProxy.NAME) as MediaProxy;
		}
		
		override public function listNotificationInterests():Array
		{
			return [NotificationType.MEDIA_ELEMENT_READY, NotificationType.ROOT_RESIZE];
		}
		
		override public function handleNotification(notification:INotification):void
		{
			//replace created element with VPAID element
			if (notification.getName() == NotificationType.MEDIA_ELEMENT_READY ) {
				var player:MediaPlayer = (facade.retrieveMediator(KMediaPlayerMediator.NAME) as KMediaPlayerMediator).player;
				var width: Number = player.mediaWidth ? player.mediaWidth : _adDimensions.width;
				var height: Number = player.mediaHeight ? player.mediaHeight : _adDimensions.height;
				_vpaid = new VPAIDElement( new URLResource(_mediaProxy.vo.entryUrl), new SWFLoader(), width, height);	
				if ( _adParameters ) {
					VPAIDMetadata(_vpaid.getMetadata("org.osmf.vpaid.metadata.VPAIDMetadata")).addValue("adParameters", _adParameters);
				}
				
				//add vpaid events listeners to notify js
				for (var i:int = 0; i<_eventsList.length; i++) {
					_vpaid.addEventListener(_eventsList[i], onEvent);
				}
				player.media = _vpaid;
			}
			// handle player resize
			if (notification.getName() == NotificationType.ROOT_RESIZE ) {
				var dataObj:Object = new Object();
				dataObj.width = _adDimensions.width ? _adDimensions.width : notification.getBody().width;
				dataObj.height = _adDimensions.height ? _adDimensions.height : notification.getBody().height;
				dataObj.viewMode = dataObj.width > 1000 ? "fullscreen" : "normal";
				VPAIDMetadata(_vpaid.getMetadata("org.osmf.vpaid.metadata.VPAIDMetadata")).addValue(VPAIDMetadata.RESIZE_AD, dataObj);
			}
		}
		
		private function onEvent(e:Event):void {
			if (e.type == "AdLinearChange"){
				var adLinear:Boolean = VPAIDMetadata(_vpaid.getMetadata("org.osmf.vpaid.metadata.VPAIDMetadata")).getValue("adLinear");
				facade.sendNotification(e.type, {"AdLinear": adLinear});
			}else{
				facade.sendNotification(e.type);
			}					
		}
	}
}