trigger AccountTrigger on Account (before insert, before update, before delete) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) BrewAccountHandler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) BrewAccountHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        if (Trigger.isDelete) BrewAccountHandler.beforeDelete(Trigger.old);
    }
}
