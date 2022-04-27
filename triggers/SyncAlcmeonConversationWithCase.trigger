trigger SyncAlcmeonConversationWithCase on Case (after update) {
    List<alcmeon__Conversation__c> alcmeonConversationsToUpdate = new List<alcmeon__Conversation__c>();

    for(alcmeon__Conversation__c alcmeonConvToUpdate : [ 
        SELECT Id, alcmeon__To_SF_Queue_Id__c, alcmeon__From_SF_Queue_Id__c, alcmeon__Contact__c, alcmeon__Account__c, alcmeon__Case__c
        FROM alcmeon__Conversation__c
        WHERE alcmeon__Case__c IN : Trigger.New ]) {

        Case updatedCase = trigger.newMap.get(alcmeonConvToUpdate.alcmeon__Case__c);
        System.debug('Updated case:' + updatedCase);
        System.debug('Alcmeon conv to update:' + alcmeonConvToUpdate);

        Boolean needsUpdate = false;

        // Update only if the value is different, in order to avoid triggers cycles
        if (alcmeonConvToUpdate.alcmeon__To_SF_Queue_Id__c != updatedCase.OwnerId &&
            alcmeonConvToUpdate.alcmeon__From_SF_Queue_Id__c != updatedCase.OwnerId) {

            alcmeonConvToUpdate.alcmeon__From_SF_Queue_Id__c = updatedCase.OwnerId;
            needsUpdate = true;
        }

        if (alcmeonConvToUpdate.alcmeon__Contact__c != updatedCase.ContactId) {

            alcmeonConvToUpdate.alcmeon__Contact__c = updatedCase.ContactId;
            needsUpdate = true;
        }

        if (alcmeonConvToUpdate.alcmeon__Account__c != updatedCase.AccountId) {

            alcmeonConvToUpdate.alcmeon__Account__c = updatedCase.AccountId;
            needsUpdate = true;
        }

        if (needsUpdate) {
            alcmeonConversationsToUpdate.add(alcmeonConvToUpdate);
        }
    }

    if(alcmeonConversationsToUpdate.size() > 0) {
        System.debug('Bulk update of ' + alcmeonConversationsToUpdate.size() + ' alcmeon conversations.');
        update alcmeonConversationsToUpdate;
    }
}