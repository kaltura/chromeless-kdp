package
{

	import com.kaltura.kdpfl.plugin.IPlugin;
	import com.kaltura.kdpfl.plugin.IPluginFactory;
	import com.kaltura.kdpfl.plugin.VPaidPluginMediator;
	
	import flash.display.Sprite;
	import flash.system.Security;
	
	import org.puremvc.as3.interfaces.IFacade;
	
	
	public class VPaidPlugin extends Sprite implements IPluginFactory, IPlugin
	{	
		public function VPaidPlugin()
		{
			Security.allowDomain("*");
		}
		
		public function create (pluginName : String =null) : IPlugin
		{
			return this;
		}
		
		public function initializePlugin(facade:IFacade):void
		{
			var vpaidMediator:VPaidPluginMediator = new VPaidPluginMediator();
			facade.registerMediator(vpaidMediator);
		}
		
		public function setSkin(styleName:String, setSkinSize:Boolean=false):void
		{
			// Do nothing here
		}
	}
}