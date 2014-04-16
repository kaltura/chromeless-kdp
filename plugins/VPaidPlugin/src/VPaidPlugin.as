package
{

    import com.kaltura.kdpfl.model.ConfigProxy;
    import com.kaltura.kdpfl.plugin.IPlugin;
    import com.kaltura.kdpfl.plugin.IPluginFactory;
    import com.kaltura.kdpfl.plugin.VPaidPluginMediator;
    
    import flash.display.Sprite;
    import flash.system.Security;
    
    import org.puremvc.as3.interfaces.IFacade;
    
    
    public class vpaidPlugin extends Sprite implements IPluginFactory, IPlugin
    {    
        public var adParameters:String;
        
        public function vpaidPlugin()
        {
            Security.allowDomain("*");
        }
        
        public function create (pluginName : String =null) : IPlugin
        {
            return this;
        }
        
        public function initializePlugin(facade:IFacade):void
        {
            var configProxy:ConfigProxy = facade.retrieveProxy(ConfigProxy.NAME) as ConfigProxy;
            if ( configProxy.vo.flashvars.vpaidAdParameters ) {
                adParameters = unescape( configProxy.vo.flashvars.vpaidAdParameters );
            }
            var vpaidMediator:VPaidPluginMediator = new VPaidPluginMediator( adParameters );
            facade.registerMediator(vpaidMediator);
        }
        
        public function setSkin(styleName:String, setSkinSize:Boolean=false):void
        {
            // Do nothing here
        }
    }
}