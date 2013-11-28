package com.kaltura.kdpfl.controller
{
	import com.kaltura.kdpfl.model.ConfigProxy;
	import com.kaltura.kdpfl.model.ExternalInterfaceProxy;
	import com.kaltura.kdpfl.model.FuncsProxy;
	import com.kaltura.kdpfl.model.MediaProxy;
	import com.kaltura.kdpfl.model.PlayerStatusProxy;
	import com.kaltura.kdpfl.model.SequenceProxy;
	import com.kaltura.kdpfl.model.type.NotificationType;
	import com.kaltura.kdpfl.util.Functor;
	import com.kaltura.kdpfl.view.RootMediator;
	import com.kaltura.kdpfl.view.media.KMediaPlayerMediator;
	
	import flash.events.MouseEvent;
	
	import org.osmf.media.MediaPlayer;
	import org.osmf.media.MediaPlayerSprite;
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.command.SimpleCommand;

	/**
	 * This class is responsible for pre-initialization activities. 
	 */	
	public class StartupCommand extends SimpleCommand
	{
		/**
		 * Register all Proxies and Mediators before calling Application initialization  
		 * @param note
		 */		
		override public function execute(notification:INotification):void
		{
			//we set the current flashvar first and override them with stage flashvars if needed
			facade.registerProxy( new ConfigProxy( (notification.getBody()).root.loaderInfo.parameters) ); //register the config proxy
			facade.registerProxy( new MediaProxy() ); //register the media proxy
			facade.registerProxy( new SequenceProxy() );
			facade.registerProxy( new ExternalInterfaceProxy() ); //register the external interface proxy
			facade.registerProxy( new PlayerStatusProxy()); 
			Functor.globalsFunctionsObject = new FuncsProxy(); 
			
			var player:MediaPlayer = new MediaPlayer();
			var sp:MediaPlayerSprite = new MediaPlayerSprite(player);
			var rootMediator:RootMediator = new RootMediator(notification.getBody().root, sp);
			facade.registerMediator(  new RootMediator(notification.getBody().root, sp ));
			(notification.getBody().root).addChild(sp);
			facade.registerMediator( new KMediaPlayerMediator( KMediaPlayerMediator.NAME , sp ));

            //send notification to start the macro command process
            sendNotification( NotificationType.INITIATE_APP );
		}
		
	}
}