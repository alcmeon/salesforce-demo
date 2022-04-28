# salesforce-demo
This repository contains demo code for the [Alcmeon for Salesforce package](https://developers.alcmeon.com/docs/salesforce-changelog).

> **Disclaimer**
>
> The code in this repository is provided as an example to ease the integration of our [Alcmeon for Salesforce package](https://developers.alcmeon.com/docs/salesforce-changelog) in your Salesforce organization. 
> 
> Please note that if your Salesforce organization has been customized, these examples are meant to inspire you but may not work properly. Therefore, no technical support on these examples will be provided.

## Apex triggers

The demo [triggers](https://github.com/alcmeon/salesforce-demo/tree/main/triggers) can be used to synchronize `alcmeon__Conversation__c` and `Case` objects. 

Full documentation: https://developers.alcmeon.com/docs/sf-configuration-of-salesforce-organization#apex-triggers

## Aura component to notify agents of new messages

This feature notifies the Customer Support Agent when a new message is received for a conversation of a `Case` other than the opened one.

![sf-configure-org-tab-notif](https://user-images.githubusercontent.com/80467679/165757140-93231a24-c4e0-489d-8de3-a1c0c67a2310.png)

It relies on a Salesforce `PushTopic` to watch the `alcmeon__Conversation__c` object for new messages.

> This object is available starting from API version 21.0. 
> 
> You can check the version for your organization by navigating to the `Setup`:
> * In the 'Quick Find' search box type, `Apex Classes`
> * Click `Apex Classes` in the setup menu options
> * Click the `New` button and on the resulting page open the `Version Settings` tab.
> * The top most value available in the `Version` column's drop down is your org's current API version.
>
> In this code, we use the API version 37. Feel free to modify it accordingly.

### Create a Push Topic channel

To create the push topic channel from your organization:
* In the Developer Console, open `Debug` > `Open Execute Anonymous Window`.
* In the popup window, paste the following piece of code:

```java
List<PushTopic> pts = [SELECT Id FROM PushTopic WHERE Name = 'AlcConversationUrlUpdate'];
if (pts.isEmpty()) {
  PushTopic pushTopic = new PushTopic();
  pushTopic.Name = 'AlcConversationUrlUpdate';
  pushTopic.Query = 'SELECT Id, alcmeon__url__c, alcmeon__Case__c FROM alcmeon__Conversation__c';
  pushTopic.ApiVersion = 37.0;
  pushTopic.NotifyForOperationCreate = false;
  pushTopic.NotifyForOperationUpdate = true;
  pushTopic.NotifyForOperationUndelete = false;
  pushTopic.NotifyForOperationDelete = false;
  pushTopic.NotifyForFields = 'Referenced';
  insert pushTopic;
}
```

To verify that the the Push Topic has been added correctly:

* Open the `QueryEditor` on the bottom menu.
* Paste the query `select id, name, query from pushtopic`.
* Click on Execute.
* You can check the result of the query in the main window .

### Create the Aura component

Once the Push Topic has been created, you have to create the aura component that will listen for notifications. 

* Open the Developer Console.
* Click on `File` > `New` > `Lightning component`.
* Insert the name `BackgroundAlcCaseOnChange` and click on `Submit`.

> NB: if a popup message appears saying that the name already exists or was previously used, just do a small modification and remember the new name when you will add this component to the UI.

* In the `Component` section, copy-paste the code of [BackgroundAlcCaseOnChange.cmp](aura/BackgroundAlcCaseOnChange/BackgroundAlcCaseOnChange.cmp).
* In the `Controller` section, copy-paste the code of [BackgroundAlcCaseOnChangeController.js](/aura/BackgroundAlcCaseOnChange/BackgroundAlcCaseOnChangeController.js).
* Save with `CTRL + S` and exit.

After creating the aura component you need to add it to the app:

* From the `Setup`, open the `Apps` section from the left side menu.
* Open `App Manager` and edit the `Service Console` application.
* From the `Utility Items` section, click on `Add Utility Item`.
* Look for the `Custom` section at the bottom, and add the item `BackgroundAlcCaseOnChange` (or the name you previously gave to your component).
* Save and refresh the Service Console page to activate this feature.
