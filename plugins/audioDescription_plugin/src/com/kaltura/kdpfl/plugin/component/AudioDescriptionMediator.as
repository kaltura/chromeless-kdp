package com.kaltura.kdpfl.plugin.component
{
	import com.kaltura.kdpfl.model.type.NotificationType;
	import com.kaltura.kdpfl.view.media.KMediaPlayerMediator;
	
	import flash.display.DisplayObject;
	import flash.events.IOErrorEvent;
	
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.mediator.Mediator;
	

	public class AudioDescriptionMediator extends Mediator
	{
		public static const NAME:String = "audioDescriptionMediator";
		private var _entryId:String = "";
		private var _file:String = "";
		public var audioDescriptionPluginCode:AudioDescriptionPluginCode;

		public function AudioDescriptionMediator(viewComponent:Object=null)
		{
			super(NAME, viewComponent);
		}
		
		override public function listNotificationInterests():Array
		{
			return  [
						NotificationType.PLAYER_PLAYED,
						NotificationType.PLAYER_PLAY_END,
						NotificationType.PLAYER_PAUSED,
						NotificationType.DO_SEEK,
						"audioDescriptionClicked",
						"audioDescriptionLoadFile"
					];
		}
		
		override public function handleNotification(note:INotification):void
		{
			var eventName:String = note.getName();	

			switch (eventName)
			{
				case NotificationType.PLAYER_PLAYED:
				{
					(view as AudioDescription).play();
				}
				break;

				case NotificationType.PLAYER_PLAY_END:
				{
					(view as AudioDescription).setSeek(0);
				}
				break;

				case NotificationType.PLAYER_PAUSED:
				{
					(view as AudioDescription).pause();
				}
				break;

				case NotificationType.DO_SEEK:
				{
					var seekTo : Number = Number(note.getBody());
					(view as AudioDescription).setSeek(seekTo * 1000);
					//pause play to seek in Sound obj
					if ( (facade.retrieveMediator(KMediaPlayerMediator.NAME) as KMediaPlayerMediator).player.playing ) {
						(view as AudioDescription).pause();
						(view as AudioDescription).play();
					}
					
				}
				break;

				case "audioDescriptionClicked":
				{
					(view as AudioDescription).audioDescriptionClicked();
				}
				break;
				
				case "audioDescriptionLoadFile":
				{
					loadFile( note.getBody().file );
				}
				break;
			}
		}
		
		/**
		 * load the given fileUrl and saves it as _file 
		 * @param fileUrl
		 * 
		 */		
		public function loadFile(fileUrl:String):void 
		{
			_file = fileUrl;
			(view as AudioDescription).addEventListener(IOErrorEvent.IO_ERROR, onAudioFileError );
			(view as AudioDescription).loadFile(_file);
		}
		
		public function setVolume(volume:Number):void {
			(view as AudioDescription).setVolume (volume);
		}
		
		private function onAudioFileError (evt : IOErrorEvent) : void
		{
			trace ("Failed to create audio file");
		}

		public function set file(value:String) : void
		{
			_file = value;
		}
		
		public function get view() : DisplayObject
		{
			return viewComponent as DisplayObject;
		}
	}
}