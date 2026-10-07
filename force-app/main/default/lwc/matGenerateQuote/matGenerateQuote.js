import { api, LightningElement, wire } from "lwc";
import { IsConsoleNavigation, openTab } from "lightning/platformWorkspaceApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import { RefreshEvent } from "lightning/refresh";
import generateQuote from "@salesforce/apex/MatQuoteService.generateQuoteForPreview";
import generating from "@salesforce/label/c.Mat_Quote_Generating";
import generated from "@salesforce/label/c.Mat_Quote_Generated";
import generationError from "@salesforce/label/c.Mat_Quote_GenerationError";

export default class MatGenerateQuote extends LightningElement {
  @api recordId;
  isGenerating = false;
  @wire(IsConsoleNavigation) isConsoleNavigation;

  @api
  async invoke() {
    if (this.isGenerating) {
      return;
    }
    this.isGenerating = true;
    this.toast(generating, "info");
    try {
      const result = await generateQuote({ opportunityId: this.recordId });
      this.toast(generated, "success");
      this.dispatchEvent(new RefreshEvent());
      // A Files refresh is helpful, but must not turn a saved PDF into a failure.
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]).catch(
        () => {}
      );
      const quoteId = encodeURIComponent(result.quoteId);
      const quotePage = encodeURIComponent(
        `/lightning/r/Quote/${result.quoteId}/view`
      );
      // Console navigation otherwise keeps Opportunity as the active publisher.
      // Focus the Quote workspace before opening its quick action.
      if (this.isConsoleNavigation) {
        await openTab({ recordId: result.quoteId, focus: true });
      }
      window.open(
        `/lightning/action/quick/Quote.Mat_VerCotizacion?recordId=${quoteId}&backgroundContext=${quotePage}`,
        "_self"
      );
    } catch (error) {
      this.toast(error?.body?.message || generationError, "error");
    } finally {
      this.isGenerating = false;
    }
  }

  toast(message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({ title: "Cotización Match", message, variant })
    );
  }
}
