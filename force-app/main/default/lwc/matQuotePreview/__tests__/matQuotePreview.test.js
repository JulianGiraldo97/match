import { createElement } from "lwc";
import MatQuotePreview from "c/matQuotePreview";
import getPreviewContext from "@salesforce/apex/MatQuotePdfFileWriter.getPreviewContext";
import { navigateMock } from "lightning/navigation";
import emailError from "@salesforce/label/c.Mat_Quote_EmailError";

jest.mock(
  "@salesforce/apex/MatQuotePdfFileWriter.getPreviewContext",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock("lightning/navigation", () => {
  const navigateSpy = jest.fn();
  const navigate = Symbol("Navigate");
  const NavigationMixin = (Base) =>
    class extends Base {
      [navigate](reference) {
        navigateSpy(reference);
      }
    };
  NavigationMixin.Navigate = navigate;
  return { NavigationMixin, navigateMock: navigateSpy };
});

const saved = {
  quoteId: "0Q0000000000001AAA",
  quoteDocumentId: "0QD000000000001AAA",
  contentDocumentId: "069000000000001AAA",
  contentVersionId: "068000000000001AAA"
};
const flush = async () => {
  await Promise.resolve();
  await Promise.resolve();
};
function createPreview() {
  const element = createElement("c-mat-quote-preview", { is: MatQuotePreview });
  element.recordId = saved.quoteId;
  document.body.appendChild(element);
  return element;
}
function button(element, label) {
  return [...element.shadowRoot.querySelectorAll("lightning-button")].find(
    (b) => b.label === label
  );
}

describe("Saved Match PDF and native email handoff", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it("loads the selected Quote and previews its stored PDF", async () => {
    const element = createPreview();
    await flush();
    expect(getPreviewContext.getLastConfig()).toEqual({
      quoteId: saved.quoteId
    });
    getPreviewContext.emit(saved);
    await flush();
    expect(element.shadowRoot.querySelector("iframe").getAttribute("src")).toBe(
      `/servlet/servlet.FileDownload?file=${saved.quoteDocumentId}`
    );
    expect(button(element, "Enviar por correo").disabled).toBe(false);
  });

  it("hands off the saved attachment once and prevents repeated email clicks", async () => {
    const element = createPreview();
    const send = jest.fn();
    element.addEventListener("sendquote", send);
    getPreviewContext.emit(saved);
    await flush();
    button(element, "Enviar por correo").click();
    button(element, "Enviar por correo").click();
    await flush();
    expect(send).toHaveBeenCalledTimes(1);
    expect(send.mock.calls[0][0].detail).toEqual({
      contentDocumentId: saved.contentDocumentId
    });
    expect(button(element, "Enviar por correo").disabled).toBe(true);
  });

  it("keeps the saved PDF and allows retry when the native composer fails", async () => {
    const element = createPreview();
    getPreviewContext.emit(saved);
    await flush();
    button(element, "Enviar por correo").click();
    element.showEmailError();
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      emailError
    );
    expect(element.shadowRoot.querySelector("iframe")).not.toBeNull();
    expect(button(element, "Enviar por correo").disabled).toBe(false);
  });

  it("permits reopening email after the user returns from the composer", async () => {
    const element = createPreview();
    const send = jest.fn();
    element.addEventListener("sendquote", send);
    getPreviewContext.emit(saved);
    await flush();
    button(element, "Enviar por correo").click();
    element.finishOpeningEmail();
    await flush();
    button(element, "Enviar por correo").click();
    expect(send).toHaveBeenCalledTimes(2);
  });

  it("blocks email when the saved document cannot be read", async () => {
    const element = createPreview();
    getPreviewContext.error({ message: "PDF no disponible" });
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "PDF no disponible"
    );
    expect(element.shadowRoot.querySelector("iframe")).toBeNull();
    expect(button(element, "Enviar por correo").disabled).toBe(true);
  });

  it("opens native Files preview for the same stored document", async () => {
    const element = createPreview();
    getPreviewContext.emit(saved);
    await flush();
    button(element, "Abrir archivo").click();
    expect(navigateMock).toHaveBeenCalledWith({
      type: "standard__namedPage",
      attributes: { pageName: "filePreview" },
      state: {
        recordIds: saved.contentDocumentId,
        selectedRecordId: saved.contentDocumentId
      }
    });
  });

  it("closes preview without requesting email", () => {
    const element = createPreview();
    const close = jest.fn();
    const send = jest.fn();
    element.addEventListener("closepreview", close);
    element.addEventListener("sendquote", send);
    button(element, "Cerrar").click();
    expect(close).toHaveBeenCalledTimes(1);
    expect(send).not.toHaveBeenCalled();
  });
});
