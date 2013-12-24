package {
	import com.kaltura.kdpfl.plugin.IPlugin;
	import com.kaltura.kdpfl.plugin.component.AudioDescription;
	import com.kaltura.kdpfl.plugin.component.AudioDescriptionMediator;
	
	import fl.core.UIComponent;
	
	import org.puremvc.as3.interfaces.IFacade;

	public class AudioDescriptionPluginCode extends UIComponent implements IPlugin
	{
		private var _attributeAudioDescription : String;
		private var _audioDescriptionMediator : AudioDescriptionMediator;
		private var _file:String = "";
		private var _volume:Number = 1;
		/**
		 * state of audio description plugin 
		 */		
		public var state:Boolean = true;
		
		/**
		 * Constructor 
		 * 
		 */		
		public function AudioDescriptionPluginCode()
		{
		}

		/**
		 * volume of audio description. should be between 0-1 
		 */
		public function get volume():Number
		{
			return _volume;
		}

		/**
		 * @private
		 */
		public function set volume(value:Number):void
		{
			if (value && value!=_volume)
			{
				_volume = value;
				if ( _audioDescriptionMediator )
					_audioDescriptionMediator.loadFile(_file);
			}
		}

		/**
		 *  
		 * @param facade
		 * 
		 */		
		public function initializePlugin( facade : IFacade ) : void
		{

			// Register Mideator
			_audioDescriptionMediator = new AudioDescriptionMediator( new AudioDescription() );
			_audioDescriptionMediator.audioDescriptionPluginCode = this;
			facade.registerMediator( _audioDescriptionMediator);
			_audioDescriptionMediator.setVolume( volume );
			if ( file )
				_audioDescriptionMediator.loadFile( file );
		}
		
 		public function setSkin(styleName:String, setSkinSize:Boolean=false):void{}
 		
		public function set attributeAudioDescription( value : String ) : void
		{
			trace("attributeAudioDescription: " + value);
			attributeAudioDescription = value;
		//	_audioDescriptionMediator.view.alpha = 0.8; //Example...
		}
		
		public function get attributeAudioDescription() : String
		{
			return attributeAudioDescription;
		}		
 		
		public function set file( value : String ) : void
		{
			if (value && value!=_file)
			{
				_file = value;
				if ( _audioDescriptionMediator )
					_audioDescriptionMediator.loadFile(_file);
			}
		}
		
		
		
		public function get file ():String{
			return _file;
		}
	}
}
