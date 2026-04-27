/**
 * Account trigger handler. Responsibilities:
 *   - Normalize website URLs and phone numbers on insert/update.
 *   - Flag accounts for credit hold when LifetimeValue__c drops negative.
 *   - Block deletion of accounts that still have active subscriptions.
 */
public with sharing class BrewAccountHandler {

    public static void beforeInsert(List<Account> accounts) {
        for (Account a : accounts) {
            normalizeWebsite(a);
            normalizePhone(a);
            if (a.LoyaltyTier__c == null) a.LoyaltyTier__c = 'Bronze';
            if (a.LoyaltyPoints__c == null) a.LoyaltyPoints__c = 0;
            if (a.LifetimeValue__c == null) a.LifetimeValue__c = 0;
        }
    }

    public static void beforeUpdate(List<Account> accounts, Map<Id, Account> oldMap) {
        for (Account a : accounts) {
            Account prev = oldMap.get(a.Id);
            if (a.Website != prev.Website)  normalizeWebsite(a);
            if (a.Phone   != prev.Phone)    normalizePhone(a);

            if (a.LifetimeValue__c != null && a.LifetimeValue__c < 0 && a.OnCreditHold__c == false) {
                a.OnCreditHold__c     = true;
                a.CreditHoldReason__c = 'Negative lifetime value detected';
            }
        }
    }

    public static void beforeDelete(List<Account> accounts) {
        Set<Id> ids = new Set<Id>();
        for (Account a : accounts) ids.add(a.Id);
        Map<Id, Integer> subsCount = new Map<Id, Integer>();
        for (AggregateResult r : [
            SELECT Account__c accId, COUNT(Id) cnt
            FROM Subscription__c
            WHERE Account__c IN :ids AND Status__c = 'Active'
            GROUP BY Account__c
        ]) {
            subsCount.put((Id) r.get('accId'), (Integer) r.get('cnt'));
        }
        for (Account a : accounts) {
            Integer n = subsCount.get(a.Id);
            if (n != null && n > 0) {
                a.addError('Cannot delete account with ' + n + ' active subscription(s)');
            }
        }
    }

    private static void normalizeWebsite(Account a) {
        if (String.isBlank(a.Website)) return;
        String w = a.Website.trim().toLowerCase();
        if (!w.startsWith('http://') && !w.startsWith('https://')) w = 'https://' + w;
        a.Website = w;
    }

    private static void normalizePhone(Account a) {
        if (String.isBlank(a.Phone)) return;
        String digits = a.Phone.replaceAll('[^0-9+]', '');
        if (digits.startsWith('00')) digits = '+' + digits.substring(2);
        a.Phone = digits;
    }
}
