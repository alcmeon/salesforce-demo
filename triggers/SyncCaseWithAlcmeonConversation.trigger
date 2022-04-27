trigger SyncCaseWithAlcmeonConversation on alcmeon__Conversation__c (before insert, after update) {
 
   Map<Id, alcmeon__Conversation__c> caseIdToAlcConvForUpdateMap = new Map<Id, alcmeon__Conversation__c>();
   Map<Id, String> convIdToDescriptionMap = new Map<Id, String>();
 
   for(alcmeon__Conversation__c newAlcConv: Trigger.New) {
       String description = 'Social media: ' + String.valueOf(newAlcConv.alcmeon__Social_media_type__c) + '\n' +
           'Account: ' + String.valueOf(newAlcConv.alcmeon__Social_media_account__c) + '\n' +
           'Url: ' + String.valueOf(newAlcConv.alcmeon__url__c);
       convIdToDescriptionMap.put(newAlcConv.Id, description);
 
       if (newAlcConv.alcmeon__Case__c != null) {
           caseIdToAlcConvForUpdateMap.put(newAlcConv.alcmeon__Case__c, newAlcConv);
       }
 
       if(Trigger.isInsert) { // alcmeon__Case__c == null
           String caseSubject = 'Conversation with: ' + String.valueOf(newAlcConv.alcmeon__User_name__c);
           Integer maxLength = 255;
           if(caseSubject.length() > maxLength ){
               System.debug('Subject [' + caseSubject + '] length is higher than the 255 characters limit of the field: truncate it');
               caseSubject = caseSubject.substring(0, maxLength);
           }
           // Create a new Case and put it in routing queue
           Case convCaseToInsert = new Case(
               AccountId = newAlcConv.alcmeon__Account__c,
               ContactId = newAlcConv.alcmeon__Contact__c,
               Subject=caseSubject,
               Description = description,
               Origin=String.valueOf(newAlcConv.alcmeon__Social_media_type__c));

           if (newAlcConv.alcmeon__To_SF_Queue_Id__c != null &&
            newAlcConv.alcmeon__Status__c != 'Closed') { // Don't route an already closed conversation
               convCaseToInsert.OwnerId = newAlcConv.alcmeon__To_SF_Queue_Id__c;
           }

           insert convCaseToInsert;
 
           // Update Alcmeon Conversation with the new Case Id
           newAlcConv.alcmeon__Case__c = convCaseToInsert.Id;
       }
   }
 
   if(Trigger.isUpdate) {
 
       Map<Id, Case> caseIdToCaseWithAlcConvMap = new Map<Id, Case>(
           [
               SELECT Id, AccountId, ContactId, OwnerId, Status
               FROM Case
               WHERE id IN : caseIdToAlcConvForUpdateMap.keySet()
           ]
       );
       
       // NB: AgentWork are to be used only if you activate Omnichannel in your Salesforce organization.
       Map<Id, AgentWork> caseIdToAssignedAgentWorkMap = new Map<Id, AgentWork>();
       for(AgentWork assignedAgentWork : [
           SELECT WorkItemId, Status
           FROM AgentWork
           WHERE WorkItemId IN :caseIdToAlcConvForUpdateMap.keySet() AND Status IN ('Assigned', 'Opened')
       ]) {
           caseIdToAssignedAgentWorkMap.put(assignedAgentWork.WorkItemId, assignedAgentWork);
       }
 
       List<Id> caseOwnerIds = new List<Id>();
       for (ID caseId : caseIdToCaseWithAlcConvMap.keyset()) {
           caseOwnerIds.add(caseIdToCaseWithAlcConvMap.get(caseId).OwnerId);
       }
       Map<Id, Group> caseOwnerIdToQueueOwnerMap = new Map<Id, Group>(
           [
               SELECT Id, Name FROM Group WHERE Type='Queue' AND Id In :caseOwnerIds
           ]
       );
 
       List<Case> casesToUpdate = new List<Case>();
       for(ID caseId : caseIdToCaseWithAlcConvMap.keySet()) {
 
           Case convCaseToUpdate = caseIdToCaseWithAlcConvMap.get(caseId);
           alcmeon__Conversation__c alcConvUpdated = caseIdToAlcConvForUpdateMap.get(convCaseToUpdate.Id);
 
           // Avoid triggers cycles
           Boolean needsUpdate = false;
 
           Boolean hasNewMessage = alcConvUpdated.alcmeon__url__c != Trigger.oldMap.get(alcConvUpdated.Id).alcmeon__url__c;
           // If there's a new message then update the description and put it back in Case queue again
           if (hasNewMessage) {
               convCaseToUpdate.Description = convIdToDescriptionMap.get(alcConvUpdated.Id);
               needsUpdate = true;
           }
 
           // Update Case Account/Contact only if has changed, to avoid triggers cycles
           if (convCaseToUpdate.AccountId != alcConvUpdated.alcmeon__Account__c) {
               convCaseToUpdate.AccountId = alcConvUpdated.alcmeon__Account__c;
               needsUpdate = true;
           } 
           if (convCaseToUpdate.ContactId != alcConvUpdated.alcmeon__Contact__c) {
               convCaseToUpdate.ContactId = alcConvUpdated.alcmeon__Contact__c;
               needsUpdate = true;
           }
 
           // Put the case in the specified queue, if needed
           Boolean isTransferedToSalesforce = alcConvUpdated.alcmeon__To_SF_Queue_Id__c != null;
           Boolean isStayingInSameQueue = alcConvUpdated.alcmeon__To_SF_Queue_Id__c == Trigger.oldMap.get(alcConvUpdated.Id).alcmeon__To_SF_Queue_Id__c;
           Boolean isNewQueue = !isStayingInSameQueue;
 
           if (isTransferedToSalesforce &&
               (isStayingInSameQueue && hasNewMessage || isNewQueue)) {
 
                   Boolean isAssignedToAgent = caseIdToAssignedAgentWorkMap.get(convCaseToUpdate.Id) != null;
                   Boolean isOwnedByQueue = caseOwnerIdToQueueOwnerMap.get(convCaseToUpdate.OwnerId) != null;
 
                   // Put in the queue again if it's not being handled by an agent
                   // or if had been transferred to some queue (to Alcmeon for example)
                   if (!isAssignedToAgent || isOwnedByQueue) {
                       convCaseToUpdate.OwnerId = alcConvUpdated.alcmeon__To_SF_Queue_Id__c;
                       needsUpdate = true;
                   }
               }
 
           if (needsUpdate) {
                // Re-open case if it was closed
                if(convCaseToUpdate.Status == 'Closed') {
                    convCaseToUpdate.Status = 'In Progress';
                }
                System.debug('Case to update:' + convCaseToUpdate);
                casesToUpdate.add(convCaseToUpdate);
           }
       }
       System.debug('Bulk update of ' + casesToUpdate.size() + ' cases');
       update casesToUpdate;
   }
}
