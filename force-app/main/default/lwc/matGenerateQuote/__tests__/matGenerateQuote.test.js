import { createElement } from "lwc";
import MatGenerateQuote from "c/matGenerateQuote";
import generateQuote from "@salesforce/apex/MatQuoteService.generateQuoteForPreview";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
const ShowToastEventName = "lightning__showtoast";
import { RefreshEventName } from "lightning/refresh";
import generationError from "@salesforce/label/c.Mat_Quote_GenerationError";

jest.mock(
  "@salesforce/apex/MatQuoteService.generateQuoteForPreview",
  () => ({ default: jest.fn() }),
  { virtual: true }
);


function createAction() {
  const element = createElement("c-mat-generate-quote", {
    is: MatGenerateQuote
  });
  element.recordId = "006000000000001AAA";
  document.body.appendChild(element);
  return element;
}

describe("Generate a Match quote", () => {
  beforeEach(() => {
    jest.spyOn(window, "open").mockImplementation(() => null);
    notifyRecordUpdateAvailable.mockResolvedValue();
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.restoreAllMocks();
    jest.resetAllMocks();
  });

  it("generates for the selected opportunity, refreshes Files and opens preview in Quote context", async () => {
    const documentId = "069000000000001AAA";
    generateQuote.mockResolvedValue({
      quoteId: "0Q0000000000001AAA",
      contentDocumentId: documentId
    });
    const action = createAction();
    const toast = jest.fn();
    const refresh = jest.fn();
    action.addEventListener(ShowToastEventName, toast);
    action.addEventListener(RefreshEventName, refresh);

    await action.invoke();

    expect(generateQuote).toHaveBeenCalledWith({
      opportunityId: action.recordId
    });
    expect(window.open).toHaveBeenCalledWith(
      "/lightning/action/quick/Quote.Mat_VerCotizacion?recordId=0Q0000000000001AAA&backgroundContext=%2Flightning%2Fr%2FQuote%2F0Q0000000000001AAA%2Fview",
      "_self"
    );
    expect(refresh).toHaveBeenCalledTimes(1);
    expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([
      { recordId: action.recordId }
    ]);
    expect(toast.mock.calls[1][0].detail.variant).toBe("success");
  });

  it("ignores repeated clicks while a PDF is being generated", async () => {
    let resolveGeneration;
    generateQuote.mockReturnValue(
      new Promise((resolve) => {
        resolveGeneration = resolve;
      })
    );
    const action = createAction();

    const firstInvocation = action.invoke();
    await action.invoke();
    expect(generateQuote).toHaveBeenCalledTimes(1);
    resolveGeneration({ quoteId: "0Q0000000000001AAA" });
    await firstInvocation;

    expect(window.open).toHaveBeenCalledTimes(1);
  });

  it("shows the actionable Apex error and permits a new attempt", async () => {
    generateQuote.mockRejectedValueOnce({
      body: {
        message:
          "Agrega servicios a la oportunidad antes de generar la cotización"
      }
    });
    const action = createAction();
    const toast = jest.fn();
    action.addEventListener(ShowToastEventName, toast);

    await action.invoke();
    expect(window.open).not.toHaveBeenCalled();
    expect(toast.mock.calls[1][0].detail).toEqual(
      expect.objectContaining({
        variant: "error",
        message:
          "Agrega servicios a la oportunidad antes de generar la cotización"
      })
    );

    generateQuote.mockResolvedValueOnce({ quoteId: "0Q0000000000002AAA" });
    await action.invoke();
    expect(generateQuote).toHaveBeenCalledTimes(2);
    expect(window.open).toHaveBeenCalledTimes(1);
  });

  it("uses a user-safe fallback for transport failures", async () => {
    generateQuote.mockRejectedValue(new Error("Internal transport details"));
    const action = createAction();
    const toast = jest.fn();
    action.addEventListener(ShowToastEventName, toast);

    await action.invoke();

    expect(toast.mock.calls[1][0].detail.message).toBe(generationError);
    expect(window.open).not.toHaveBeenCalled();
  });

  it("opens a saved PDF even when a background record refresh fails", async () => {
    generateQuote.mockResolvedValue({ quoteId: "0Q0000000000001AAA" });
    notifyRecordUpdateAvailable.mockRejectedValue(
      new Error("Refresh unavailable")
    );
    const action = createAction();

    await action.invoke();
    await Promise.resolve();

    expect(window.open).toHaveBeenCalledTimes(1);
  });
});
