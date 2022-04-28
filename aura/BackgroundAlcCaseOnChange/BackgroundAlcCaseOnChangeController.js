({
   onInit: function(component, event, helper) {       
       const empApi = component.find('empApi');
       const channel = '/topic/AlcConversationUrlUpdate';
        empApi.subscribe(channel, -1, $A.getCallback(eventReceived => {
           var caseIdUpdated = eventReceived.data.sobject.alcmeon__Case__c;
           var workspaceAPI = component.find("workspace");
           workspaceAPI.getAllTabInfo().then(function(allTabs) {
               allTabs.forEach(function(tab) {
                   if (tab.recordId == caseIdUpdated) {
                       if (tab.focused == false) {
                           workspaceAPI.setTabHighlighted({
                               tabId: tab.tabId,
                               highlighted: true,
                               options: {
                               pulse: true,
                               state: "warning"
                               }
                           });
                       } 
                   }
               })
           }).catch(function(error) {
               console.log(error);
           });
       }));
   },
 
   onTabFocused: function(component, event, helper) {
       var focusedTabId = event.getParam('currentTabId');
       var workspaceAPI = component.find("workspace");
       workspaceAPI.setTabHighlighted({
           tabId: focusedTabId,
           highlighted: false,
       }).catch(function(error) {
             console.log(error);
         });
     }
})
