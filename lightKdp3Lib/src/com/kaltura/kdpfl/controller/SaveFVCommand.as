package com.kaltura.kdpfl.controller
{
	import com.kaltura.kdpfl.ApplicationFacade;
	import com.kaltura.kdpfl.model.ConfigProxy;
	import com.kaltura.kdpfl.model.MediaProxy;
	import com.kaltura.kdpfl.model.type.DebugLevel;
	import com.kaltura.kdpfl.model.type.StreamerType;
	import com.kaltura.kdpfl.model.vo.ConfigVO;
	
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.command.SimpleCommand;
	import com.kaltura.kdpfl.model.strings.MessageStrings;

	/**
	 * This class syncronises between flash application parameters and parameters passed
	 * by a loading application, and saved all parameters to the config proxy. 
	 */	
	public class SaveFVCommand extends SimpleCommand
	{
		
		private var _pluginsCounter:int;
		private var _config:ConfigProxy;
		
		/**
		 * Set the flashvars into the Config Proxy
		 * @param note
		 * 
		 */		
		override public function execute(note:INotification):void
		{
			var mediaProxy : MediaProxy = facade.retrieveProxy( MediaProxy.NAME ) as MediaProxy;
			_config = facade.retrieveProxy(ConfigProxy.NAME) as ConfigProxy;
			var flashvars:Object = (_config.getData() as ConfigVO).flashvars;
	
			if (flashvars.hasOwnProperty("streamerType"))
				mediaProxy.vo.deliveryType = flashvars.streamerType;
			
			if (flashvars.hasOwnProperty("sourceType"))
				mediaProxy.vo.sourceType = flashvars.sourceType;
			
			if ((flashvars.hasOwnProperty("twoPhaseManifest") && flashvars.twoPhaseManifest == "true") 
				|| flashvars.streamerType == StreamerType.HDNETWORK_HDS )
				mediaProxy.vo.isTwoPhaseManifest = true;
			
			if ( flashvars.streamerType == StreamerType.HDNETWORK_HDS || flashvars.streamerType  == StreamerType.HDS )
				mediaProxy.vo.isHds = true;
			
			// if mediaProtocol wasnt specified implicitly and we are using http delivery use the httpProtcol
			if (!flashvars.mediaProtocol && flashvars.streamerType != StreamerType.RTMP && flashvars.streamerType != StreamerType.LIVE)
				flashvars.mediaProtocol = flashvars.httpProtocol;

			if(flashvars.externalInterfaceDisabled == "false" || flashvars.externalInterfaceDisabled == "0")
			{
				if(!flashvars.jsCallBackReadyFunc){
					flashvars.jsCallBackReadyFunc = "jsCallbackReady";
				}
			} 
			
			if(flashvars.fileSystemMode == "true" || flashvars.fileSystemMode == "1" )
			{
				flashvars.fileSystemMode = true;
			}
			else
			{
				flashvars.fileSystemMode = false;
			}
			
			if(flashvars.disableOnScreenClick == "true" || flashvars.disableOnScreenClick == "1")
			{
				flashvars.disableOnScreenClick = true;
			}
			else
			{
				flashvars.disableOnScreenClick = false;
			}
			
			if ( flashvars.entryUrl )
				mediaProxy.vo.entryUrl = unescape( flashvars.entryUrl );
			ApplicationFacade.getInstance().debugMode = (flashvars.debugMode == "true") ?  true : false;
			ApplicationFacade.getInstance().debugLevel = (flashvars.debugLevel) ?  flashvars.debugLevel : DebugLevel.LOW;
			
			if(!flashvars.aboutPlayer)	
				flashvars.aboutPlayer= "About Kaltura's Open Source Video Player";
			
			if(!flashvars.aboutPlayerLink)
				flashvars.aboutPlayerLink= "http://corp.kaltura.com/technology/video_player";
		
			if(!flashvars.streamerType)
				flashvars.streamerType = StreamerType.HTTP;
			
			if (flashvars.hasOwnProperty("selectedFlavorIndex"))
				mediaProxy.vo.selectedFlavorIndex = flashvars.selectedFlavorIndex;
			
			if (flashvars.isLive && flashvars.isLive == "true")
				mediaProxy.vo.isLive = true;
			
			if (flashvars.isMp4 && flashvars.isMp4 == "true")
				mediaProxy.vo.isMp4 = true;
			
			MessageStrings.init(flashvars);
			
		}
		
	}
}