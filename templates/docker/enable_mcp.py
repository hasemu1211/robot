import carb
import omni.kit.app

manager = omni.kit.app.get_app().get_extension_manager()
if not manager.is_extension_enabled("isaac_sim_mcp_extension"):
    manager.set_extension_enabled("isaac_sim_mcp_extension", True)
    carb.log_info("[MCP] isaac_sim_mcp_extension enabled via startup script")
else:
    carb.log_info("[MCP] isaac_sim_mcp_extension already enabled")
