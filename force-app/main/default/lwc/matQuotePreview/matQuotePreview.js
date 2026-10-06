import { api, LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getPreviewContext from "@salesforce/apex/MatQuotePdfFileWriter.getPreviewContext";
import previewError from "@salesforce/label/c.Mat_Quote_PreviewError";
import emailError from "@salesforce/label/c.Mat_Quote_EmailError";

export default class MatQuotePreview extends NavigationMixin(LightningElement) {
  @api recordId;
  context;
  errorMessage;
  isLoading = true;
  isOpeningEmail = false;

  @wire(getPreviewContext, { quoteId: "$recordId" })
  loadPdf({ data, error }) {
    if (data) {
      this.context = data;
      this.errorMessage = undefined;
      this.isLoading = false;
    } else if (error) {
      this.context = undefined;
      this.errorMessage = error?.body?.message || previewError;
      this.isLoading = false;
    }
  }

  get pdfUrl() {
    return this.context
      ? `/servlet/servlet.FileDownload?file=${encodeURIComponent(this.context.quoteDocumentId)}`
      : undefined;
  }

  get disableEmail() {
    return !this.context || this.isOpeningEmail;
  }

  handleSend() {
    if (this.disableEmail) return;
    this.isOpeningEmail = true;
    this.errorMessage = undefined;
    this.dispatchEvent(
      new CustomEvent("sendquote", {
        detail: { contentDocumentId: this.context.contentDocumentId }
      })
    );
  }

  @api
  finishOpeningEmail() {
    this.isOpeningEmail = false;
  }

  @api
  showEmailError() {
    this.errorMessage = emailError;
    this.isOpeningEmail = false;
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("closepreview"));
  }

  handleFilePreview() {
    this[NavigationMixin.Navigate]({
      type: "standard__namedPage",
      attributes: { pageName: "filePreview" },
      state: {
        recordIds: this.context.contentDocumentId,
        selectedRecordId: this.context.contentDocumentId
      }
    });
  }
}
