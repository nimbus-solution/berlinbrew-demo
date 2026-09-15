({
    ensureMessage : function(component) {
        if (!component.get("v.message")) {
            component.set("v.message", "Fresh roasts ship every Tuesday.");
        }
    }
})
