trigger SubscriptionTrigger on Subscription__c (before insert, before update, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) BrewSubscriptionHandler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) BrewSubscriptionHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        BrewSubscriptionHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
