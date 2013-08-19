package {
	import fl.events.ComponentEvent;
	
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.system.Security;
	import flash.utils.Timer;
	import flash.utils.getDefinitionByName;
	
	/**
	 * @class ApplicationLoader
	 * This class is the preloader of the kdp3 application and its document class (root). </br>
	 * It delegates all calls to IKDP3 methods to the actual kdp3 instance, to enable
	 * communication with loading applications, etc.
	 * @author Atar
	 *
	 */
	public class ApplicationLoader extends MovieClip implements IKDP3 {
		
		/**
		 * an instance of the created application (kdp3)
		 */
		protected var _app:IKDP3;

		
		protected var _path:String;
		
		
		/**
		 * is the real app started yet
		 */
		protected var _isGoing:Boolean = false;
		
		
		/**
		 * temporarily save flashvars until _app is ready
		 */
		protected var _flashvars:Object;
		
		
		/**
		 * someone already asked to init the KDP
		 */
		protected var _shouldInit:Boolean;
	
		private var _height:Number;
		private var _width:Number;
	
		
		private var _kdp3Timer:Timer;
		
		/**
		 * in case kdp3 class wasn't found will start a timer with this delay 
		 */		
		public static const KDP3_LOAD_TIMER_DELAY:int = 100;
		/**
		 * in case kdp3 class wasn't found will start a timer and run this amount of times
		 */
		public static const KDP3_LOAD_TIMER_TRIES:int = 30;
		
		
		
		/**
		 * Constructor.
		 */
		public function ApplicationLoader() {
			this.addEventListener(ComponentEvent.HIDE, stopImmediatePropagation);
			this.addEventListener(ComponentEvent.SHOW, stopImmediatePropagation);
			Security.allowDomain("*");
			super();
			stop();
			//fix issue with FF 3.6 & wmode!="window": we already loaded the application
			if (loaderInfo.bytesLoaded == loaderInfo.bytesTotal)
				go();
			else
				loaderInfo.addEventListener(Event.COMPLETE, go);
		}
		
		
		/**
		 * concatenate the host and most of the path up to the preloader's folder
		 * or return given path, if such exist.
		 * @return full url of preloader swf
		 */
		protected function getPath():String {
			if (parameters.preloaderPath) {
				return parameters.preloaderPath;
			}
			var s:String = this.loaderInfo.url;
			var i:int = s.indexOf("kdp3.swf");
			s = s.substring(0, i);
			s += _path;
			return s;
		}
		

		/**
		 * Starts the real application by creating an instance of kdp3.
		 */
		protected function go(e:Event = null):void {
			_isGoing = true;
			loaderInfo.removeEventListener(Event.COMPLETE, go);
			nextFrame();
			
			var mainClass:Class;
			
			try 
			{
				mainClass = Class(getDefinitionByName("kdp3"));
			}
			catch (e:Error)
			{
				//fix bug on linux & FF, after load, kdp3 class wasn't ready yet
				trace ("kdp3 class wasn't found");
				if (!_kdp3Timer)
				{
					_kdp3Timer = new Timer(KDP3_LOAD_TIMER_DELAY, KDP3_LOAD_TIMER_TRIES);
					_kdp3Timer.addEventListener(TimerEvent.TIMER, go);
					_kdp3Timer.addEventListener(TimerEvent.TIMER_COMPLETE, onTimerComplete);
					_kdp3Timer.start();
				}
			}
			
			if (mainClass) {
				if (_kdp3Timer)
				{
					_kdp3Timer.stop();
					onTimerComplete();
					trace ("found kdp3 class");
				}
				_app = new mainClass();
				(_app as DisplayObject).addEventListener(Event.ADDED_TO_STAGE, onAppAddedToStage);
				addChild(_app as DisplayObject);
								
				if (_flashvars) {
					_app.flashvars = _flashvars;
				}
				if (_shouldInit) {
					_app.init();
				}
			}
		}
		
		private function onTimerComplete(event:TimerEvent = null) : void
		{
			_kdp3Timer.removeEventListener(TimerEvent.TIMER, go);
			_kdp3Timer.removeEventListener(TimerEvent.TIMER_COMPLETE, onTimerComplete);
			if (event)
			{
				trace ("kdp3 timer complete. Failed to load kdp3");
			}
		}
		
		private function onAppAddedToStage (e : Event) : void
		{
			if (_width) {
				_app.width = _width;
			}
			if (_height) {
				_app.height = _height;
			}
		}
		
		protected function stopImmediatePropagation(event:Event):void {
			event.stopImmediatePropagation();
		}
		
		/* -----------------------------------------------------------------
		* ------------------------------------------------------------------
		*		  interface methods; delegated to the kdp3 instance
		* ------------------------------------------------------------------
		* ------------------------------------------------------------------ */
		
		public function set flashvars(obj:Object):void {
			if (_app) {
				_app.flashvars = obj;
			}
			else {
				_flashvars = obj;
			}
		}
		
		
		public function get flashvars():Object {
			if (_app) {
				return _app.flashvars;
			}
			else {
				return _flashvars;
			}
		}
		
		override public function get height():Number {
			return _height;
		}
		
		
		override public function set height(value:Number):void {
			if (value == _height) return;
			//super.height = value;
			_height = value;
			if (_app) {
				_app.height = value;
			}
		}
		
		
		override public function get width():Number {
			return _width;
		}
		
		
		override public function set width(value:Number):void {
			if (value == _width) return;
			//super.width = value;
			_width = value;
			if (_app) {
				_app.width = value;
			}
		}
		
		
		/**
		 * a reference to application parameters
		 * */
		public function get parameters():Object {
			if (stage && stage.loaderInfo)
				return stage.loaderInfo.parameters;
			else
				return loaderInfo.parameters;
		}
		
		
		public function init(kml:XML = null):void {
			if (_app) {
				_app.init();
			}
			else {
				_shouldInit = true;
			}
		}
		
		
		public function sendNotification(notificationName:String, body:Object = null, type:String = null):void {
			_app.sendNotification(notificationName, body, type);
		}
		
		
		public function evaluate(expression:String):Object {
			return _app.evaluate(expression);
		}
		
		
		public function setAttribute(componentName:String, prop:String, newValue:String):void {
			_app.setAttribute(componentName, prop, newValue);
		}
		
		
		public function dispose():void {
			_app.dispose();
		}
		
	}
}