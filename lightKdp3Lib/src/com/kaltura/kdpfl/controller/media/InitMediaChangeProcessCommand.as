package com.kaltura.kdpfl.controller.media
{
	import com.kaltura.kdpfl.model.ConfigProxy;
	import com.kaltura.kdpfl.model.MediaProxy;
	import com.kaltura.kdpfl.model.PlayerStatusProxy;
	import com.kaltura.kdpfl.model.SequenceProxy;
	import com.kaltura.kdpfl.model.type.EnableType;
	import com.kaltura.kdpfl.model.type.NotificationType;
	import com.kaltura.kdpfl.model.type.SequenceContextType;
	import com.kaltura.kdpfl.view.media.KMediaPlayerMediator;
	import com.kaltura.osmf.proxy.KSwitchingProxyElement;
	
	import org.osmf.media.MediaPlayer;
	import org.osmf.media.MediaPlayerState;
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.command.SimpleCommand;
	import org.puremvc.as3.patterns.observer.Notification;
	
	/**
	 * This class is responsible for initiating media change process 
	 */	
	public class InitMediaChangeProcessCommand extends SimpleCommand
	{
		private var _mediaProxy:MediaProxy;
		/**
		 * Set the model with new entry to load 
		 * @param notification - notification which triggered the command.
		 * 
		 */		
		override public function execute(notification:INotification):void
		{
			
			var note : Object = (notification as Notification).getBody();
			var player:MediaPlayer = (facade.retrieveMediator(KMediaPlayerMediator.NAME) as KMediaPlayerMediator).player;
			if (player && player.state == MediaPlayerState.PLAYING)
				sendNotification(NotificationType.DO_PAUSE);

			var flashvars : Object = (facade.retrieveProxy(ConfigProxy.NAME) as ConfigProxy).vo.flashvars;
			
			_mediaProxy = facade.retrieveProxy( MediaProxy.NAME ) as MediaProxy;
			
			//If we did not change media as part of the sequence, we need to reset the pre and post sequence indexes.
			var sequenceProxy : SequenceProxy = facade.retrieveProxy( SequenceProxy.NAME ) as SequenceProxy;
			
			if ( (!sequenceProxy.vo.isInSequence || sequenceProxy.sequenceContext == SequenceContextType.MID) && !_mediaProxy.vo.isFlavorSwitching)
			{
				sequenceProxy.populatePrePostArr();
				sequenceProxy.initPreIndex() ;
				sequenceProxy.vo.postCurrentIndex = -1;
				sequenceProxy.vo.postSequenceComplete = false;
				sequenceProxy.vo.preSequenceComplete = false;
				sequenceProxy.vo.mainMediaVO = null;
				sequenceProxy.vo.isInSequence = false;
				if (_mediaProxy.vo.media is KSwitchingProxyElement)
					(_mediaProxy.vo.media as KSwitchingProxyElement).secondaryMediaElement = null;
			}

			if (note.hasOwnProperty("entryUrl") && note.entryUrl) {
				_mediaProxy.vo.entryUrl = note.entryUrl;
				_mediaProxy.vo.entryDuration = ( flashvars.entryDuration ) ? flashvars.entryDuration : int.MIN_VALUE;
				sendNotification(NotificationType.CHANGE_MEDIA_PROCESS_STARTED, {entryUrl: note.entryUrl});
				//set the offline message to false
				_mediaProxy.vo.isOffline = true;
				_mediaProxy.vo.isMediaDisabled = false;
				
				_mediaProxy.shouldWaitForElement = true;
				(facade.retrieveProxy( PlayerStatusProxy.NAME ) as PlayerStatusProxy).dispatchKDPReady();
				sendNotification( NotificationType.MEDIA_READY);
				sendNotification(NotificationType.READY_TO_PLAY);
				sendNotification(NotificationType.ENABLE_GUI, {guiEnabled : true , enableType : EnableType.CONTROLS});
				
				_mediaProxy.configurePlayback();
			}
			else {
				sendNotification(NotificationType.ENABLE_GUI,{guiEnabled : false , enableType : EnableType.CONTROLS});
				(facade.retrieveProxy( PlayerStatusProxy.NAME ) as PlayerStatusProxy).dispatchKDPEmpty();
				sendNotification(NotificationType.READY_TO_LOAD);
			}
		}
		
	}
}