// Builds the spreadsheet the mass-update demo imports, against the REAL Ids in
// this machine's local database. Run it through make-sheet.sh, which turns the
// CSV| lines below into a file.
//
// The values are chosen so the dry run has something to reveal:
//   - two accounts get a NEGATIVE LifetimeValue__c, which BrewAccountHandler
//     turns into OnCreditHold__c = true plus a CreditHoldReason__c the sheet
//     never mentions;
//   - one gets a bare-domain website, which the trigger rewrites to https://;
//   - one gets a messy phone, which the trigger normalises;
//   - the rest change only their lifetime value, so the report has quiet rows
//     to contrast the loud ones against.
Map<String, Decimal> newValue = new Map<String, Decimal>{
    'Kreuzberg Kaffee (demo)'            => -1250,
    'Mitte Roasters (demo)'              =>  3450,
    'Prenzlauer Bohne (demo)'            =>  -380,
    'Neukoelln Espresso Bar (demo)'      =>  1120,
    'Charlottenburg Coffee House (demo)' =>  5975,
    'Friedrichshain Filter (demo)'       =>  2400
};
Map<String, String> newWebsite = new Map<String, String>{
    'Mitte Roasters (demo)' => 'mitteroasters.de'
};
Map<String, String> newPhone = new Map<String, String>{
    'Neukoelln Espresso Bar (demo)' => '030 / 444 555'
};

System.debug('CSV|Id,Name,LifetimeValue__c,Website,Phone');
for (Account a : [SELECT Id, Name, Website, Phone FROM Account WHERE Name LIKE '%(demo)%' ORDER BY Name]) {
    String site  = newWebsite.containsKey(a.Name) ? newWebsite.get(a.Name) : a.Website;
    String phone = newPhone.containsKey(a.Name)   ? newPhone.get(a.Name)   : a.Phone;
    Decimal ltv  = newValue.get(a.Name);
    System.debug('CSV|' + a.Id + ',' + a.Name + ',' + ltv + ',' + site + ',' + phone);
}
