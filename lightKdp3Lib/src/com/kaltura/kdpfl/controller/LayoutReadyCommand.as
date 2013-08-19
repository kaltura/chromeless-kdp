package com.kaltura.kdpfl.controller
{
	import com.kaltura.kdpfl.model.ConfigProxy;
	import com.kaltura.kdpfl.model.MediaProxy;
	import com.kaltura.kdpfl.model.PlayerStatusProxy;
	import com.kaltura.kdpfl.model.SequenceProxy;
	import com.kaltura.kdpfl.model.strings.MessageStrings;
	import com.kaltura.kdpfl.model.type.NotificationType;
	import com.kaltura.kdpfl.view.controls.KTrace;
	
	import flash.events.Event;
	import flash.net.SharedObject;
	
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.command.SimpleCommand;

	/**
	 * This class defines the actions that are taken once KDP layout is ready. 
	 */
	public class LayoutReadyCommand extends SimpleCommand
	{
		
		private var _flashvars:Object;

		public function LayoutReadyCommand()
		{
			super();
		}
		
		override public function execute(notification:INotification):void
		{
			var playerStatus : PlayerStatusProxy = facade.retrieveProxy(PlayerStatusProxy.NAME) as PlayerStatusProxy;
			playerStatus.vo.kdpStatus = "ready";
			_flashvars = (facade.retrieveProxy(ConfigProxy.NAME) as ConfigProxy).vo.flashvars;
			
			var sequenceProxy : SequenceProxy = facade.retrieveProxy(SequenceProxy.NAME) as SequenceProxy;
			if (!sequenceProxy.vo.isInSequence	)
			{
				sequenceProxy.populatePrePostArr();
				sequenceProxy.initPreIndex();
			}
		//	(facade.retrieveMediator(MainViewMediator.NAME) as MainViewMediator).createContextMenu();
						
			//check if kdp is allowed to save cookies
			if (_flashvars.alertForCookies && _flashvars.alertForCookies=="true")
			{
				var cookie : SharedObject;
				try
				{
					cookie = SharedObject.getLocal("KalturaCookies");
				}
				catch (e: Error)
				{
					KTrace.getInstance().log("no permissions to access partner's file system");
				}
				if (cookie && cookie.data.allowCookies && cookie.data.allowCookies==true)
				{
					_flashvars.allowCookies = "true";
				}
				else
				{
					sendNotification(NotificationType.ALERT, {title: MessageStrings.getString('ALLOW_COOKIES_TITLE'), message: MessageStrings.getString('ALLOW_COOKIES'), buttons: [MessageStrings.getString('ALLOW'), MessageStrings.getString('DISALLOW')], callbackFunction: setAllowCookies, props: {buttonSpacing: 5}});
					//don't continue the flow until user has selected
					return;
				}
			}
			
			callChangeMedia();
		}
		
		/**
		 * call changeMedia Notification 
		 * 
		 */		
		private function callChangeMedia():void
		{
			var mediaProxy : MediaProxy = facade.retrieveProxy( MediaProxy.NAME ) as MediaProxy;
			if (mediaProxy.vo.entryUrl) {
				sendNotification( NotificationType.CHANGE_MEDIA, {entryUrl: mediaProxy.vo.entryUrl });
			}
			else {
				sendNotification( NotificationType.CHANGE_MEDIA, {entryUrl: null });
			}
		}
		
		/**
		 * callback function on "set cookies" alert.
		 * Will set allowCookies flashvar accordingly. 
		 * @param evt
		 * 
		 */		
		private function setAllowCookies(evt:Event):void 
		{
			if (evt.target.label==MessageStrings.getString('ALLOW'))
			{
				_flashvars.allowCookies = "true";
				var cookie : SharedObject;
				try
				{
					cookie= SharedObject.getLocal("KalturaCookies");
				}
				catch (e : Error)
				{
					KTrace.getInstance().log("No access to user's file system");
				}
				if (cookie)
				{
					cookie.data.allowCookies = true;
					cookie.flush();
				}
			}
			else
			{
				_flashvars.allowCookies = "false";
			}
			
			callChangeMedia();
		}
	}
	
}