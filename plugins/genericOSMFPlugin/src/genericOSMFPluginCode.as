package
{
    import com.kaltura.kdpfl.model.MediaProxy;
    import com.kaltura.kdpfl.plugin.IPlugin;
    import com.kaltura.kdpfl.plugin.KPluginEvent;
    
    import fl.core.UIComponent;
    
    import flash.display.DisplayObject;
    
    import org.osmf.events.MediaFactoryEvent;
    import org.osmf.media.DefaultMediaFactory;
    import org.osmf.media.URLResource;
    import org.puremvc.as3.interfaces.IFacade;
    /**
     * Plugin which wraps the load of an OSMF plugin into the OSMF MediaFactory of the KDP 
     * @author Hila
     * 
     */    
    public class genericOSMFPluginCode extends UIComponent implements IPlugin
    {
        public function genericOSMFPluginCode()
        {
            super();
        }
        
        protected var _pluginURL : String = "";
        protected var _localMediaFactory : DefaultMediaFactory;
        public var waitForSecondLoad:Boolean = true;
        //workaround to fix OSMF bug: the OSMF is loaded twice, we should notify plugin was loaded only on the second callback
        private var callbackCount:int;
        
        /**
         * A-sync init of the Plugin - this function begins an a-sync load process of the 
         * OSMF plugin into the MediaFactory contained by the KDP.  
         * @param facade
         * 
         */        
        public function initializePlugin(facade:IFacade):void
        {
            if (pluginURL)
            {
                _localMediaFactory = (facade.retrieveProxy(MediaProxy.NAME) as MediaProxy).vo.mediaFactory;
                var pluginResource : URLResource = new URLResource(pluginURL);
                _localMediaFactory.addEventListener(MediaFactoryEvent.PLUGIN_LOAD, onOSMFPluginLoaded);
                _localMediaFactory.addEventListener(MediaFactoryEvent.PLUGIN_LOAD_ERROR, onOSMFPluginLoadError);
                callbackCount = 0;
                _localMediaFactory.loadPlugin(pluginResource);
            }
        }
        /**
         * Listener for the LOAD_COMPLETE event.
         * @param e - MediaFactoryEvent
         * 
         */        
        protected function onOSMFPluginLoaded (e : MediaFactoryEvent) : void
        {
            if ( callbackCount > 0 || !waitForSecondLoad ) {
                dispatchEvent( new KPluginEvent (KPluginEvent.KPLUGIN_INIT_COMPLETE) );
                removeListeners();
            }
            callbackCount++;
            
        }
        /**
         * Listener for the LOAD_ERROR event.
         * @param e - MediaFactoryEvent
         * 
         */        
        protected function onOSMFPluginLoadError (e : MediaFactoryEvent) : void
        {
            if ( callbackCount > 0 || !waitForSecondLoad ) {
                dispatchEvent( new KPluginEvent (KPluginEvent.KPLUGIN_INIT_FAILED) );
                removeListeners();
            }        
            callbackCount++; 
        }
        
        public function setSkin(styleName:String, setSkinSize:Boolean=false):void
        {
        }
        
        [Bindable]
        /**
         * Getter/Setter for the pluginURL property which specifies the URL
         * from which to load the OSMF plugin to the MediaFactory. 
         * @return 
         * 
         */        
        public function get pluginURL():String
        {
            return _pluginURL;
        }
        
        public function set pluginURL(value:String):void
        {
            _pluginURL = value;
        }
        
        
        private function removeListeners():void {
            _localMediaFactory.removeEventListener(MediaFactoryEvent.PLUGIN_LOAD, onOSMFPluginLoaded);
            _localMediaFactory.removeEventListener(MediaFactoryEvent.PLUGIN_LOAD_ERROR, onOSMFPluginLoadError);
        }
    }
}