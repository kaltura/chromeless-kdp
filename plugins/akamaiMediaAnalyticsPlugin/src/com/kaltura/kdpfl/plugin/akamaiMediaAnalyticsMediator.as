package com.kaltura.kdpfl.plugin
{
	import com.akamai.playeranalytics.AnalyticsPluginLoader;
	import com.kaltura.kdpfl.model.MediaProxy;
	
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.mediator.Mediator;
	
	public class akamaiMediaAnalyticsMediator extends Mediator
	{
		public static const NAME:String = "akamaiMediaAnalyticsMediator";
		public static const SET_MEDIA_ANALYTICS_DATA:String = "setMediaAnalyticsData";
		private var _mediaProxy:MediaProxy;
	//	private var _hadBWCheck:Boolean = false;
		private var _pluginCode:akamaiMediaAnalyticsPluginCode;
		
		public function akamaiMediaAnalyticsMediator(viewComponent:Object=null)
		{
			_pluginCode = viewComponent as akamaiMediaAnalyticsPluginCode;
			super(NAME, viewComponent);
		}
		
		override public function onRegister():void
		{
			_mediaProxy = facade.retrieveProxy(MediaProxy.NAME) as MediaProxy;
			super.onRegister();
		}
		
		override public function listNotificationInterests():Array
		{
			return [ SET_MEDIA_ANALYTICS_DATA ];
		}
		
		override public function handleNotification(notification:INotification):void
		{
			switch (notification.getName())
			{
				case SET_MEDIA_ANALYTICS_DATA:
					var dataObject:Object = notification.getBody();
					for (var attr:String in dataObject) {
						if ( dataObject[attr] ) {
							if ( attr == "playerVersion" ) {
								dataObject[attr] += facade["kdpVersion"];
							}
							AnalyticsPluginLoader.setData( attr, dataObject[attr] );
						}
						
					}
					break;
			}
		}
	}
}