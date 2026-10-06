// Salesforce registers Aura controllers from a top-level object expression.
// eslint-disable-next-line no-unused-expressions
({
  openEmail: function (component, event) {
    var documentId = event.getParam("contentDocumentId");
    var args = {
      actionName: "Quote.SendEmail",
      targetFields: {
        ContentDocumentIds: { value: [documentId] },
        Subject: { value: $A.get("$Label.c.Mat_Quote_EmailSubject") }
      },
      // Selecting and populating the composer never submits the email.
      submitOnSuccess: false
    };
    component
      .find("emailActions")
      .setActionFieldValues(args)
      .then(
        $A.getCallback(function () {
          if (component.isValid()) {
            component.find("preview").finishOpeningEmail();
          }
        })
      )
      .catch(
        $A.getCallback(function () {
          if (component.isValid()) {
            component.find("preview").showEmailError();
          }
        })
      );
  },
  closePreview: function () {
    $A.get("e.force:closeQuickAction").fire();
  }
});
