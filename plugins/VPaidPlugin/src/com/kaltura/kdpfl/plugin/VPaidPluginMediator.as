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
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.mediator.Mediator;
	import org.osmf.vpaid.metadata.VPAIDMetadata;
	
	public class VPaidPluginMediator extends Mediator
	{
		public static const NAME:String = "VPaidPluginMediator";
		
		private var _eventsList:Array = ["AdLoaded", "AdImpression", "AdStopped", "AdError", "AdLog"];
		
		private var _mediaProxy:MediaProxy;
		private var _vpaid:VPAIDElement;
		private var _adParameters:String;
		
		public function VPaidPluginMediator(adParameters:String, mediatorName:String=null, viewComponent:Object=null)
		{
			_adParameters = adParameters;
			super(NAME, viewComponent);
		}
		
		override public function onRegister():void {
			_mediaProxy = facade.retrieveProxy(MediaProxy.NAME) as MediaProxy;
		}
		
		override public function listNotificationInterests():Array
		{
			return [NotificationType.MEDIA_ELEMENT_READY];
		}
		
		override public function handleNotification(notification:INotification):void
		{
			//replace created element with VPAID element
			if (notification.getName() == NotificationType.MEDIA_ELEMENT_READY ) {
				var player:MediaPlayer = (facade.retrieveMediator(KMediaPlayerMediator.NAME) as KMediaPlayerMediator).player;
				_vpaid = new VPAIDElement( new URLResource(_mediaProxy.vo.entryUrl), new SWFLoader(), player.mediaWidth, player.mediaHeight);	
				if ( _adParameters ) {
					VPAIDMetadata(_vpaid.getMetadata("org.osmf.vpaid.metadata.VPAIDMetadata")).addValue("adParameters", _adParameters);
				}
				
				//add vpaid events listeners to notify js
				for (var i:int = 0; i<_eventsList.length; i++) {
					_vpaid.addEventListener(_eventsList[i], onEvent);
				}
				player.media = _vpaid;
			}
		}
		
		private function onEvent(e:Event):void {
			facade.sendNotification(e.type);
		}
	}
}