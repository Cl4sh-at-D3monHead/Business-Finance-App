import Foundation

struct PaymentServiceConfig {
    let name: String
    let providers: [String]
    let fields: [PaymentField]

    static func configuration(
        for service: String
    ) -> PaymentServiceConfig {

        switch service {

        case "Electricity":
            return PaymentServiceConfig(
                name: service,
                providers: [
                    "TANESCO - LUKU",
                    "TANESCO - Postpaid"
                ],
                fields: [
                    PaymentField(
                        id: "meterNumber",
                        label: "Meter Number / Control Number",
                        placeholder: "Enter meter or control number"
                    )
                ]
            )

        case "Water":
            return PaymentServiceConfig(
                name: service,
                providers: [
                    "DAWASA",
                    "AUWSA",
                    "Other Water Utility"
                ],
                fields: [
                    PaymentField(
                        id: "accountNumber",
                        label: "Water Account / Control Number",
                        placeholder: "Enter account or control number"
                    )
                ]
            )

        case "Internet":
            return PaymentServiceConfig(
                name: service,
                providers: [
                    "Vodacom",
                    "Yas",
                    "Airtel",
                    "TTCL",
                    "Liquid Intelligent Technologies",
                    "Other Internet Provider"
                ],
                fields: [
                    PaymentField(
                        id: "customerNumber",
                        label: "Customer / Account Number",
                        placeholder: "Enter customer number"
                    ),
                    PaymentField(
                        id: "package",
                        label: "Package / Invoice Reference",
                        placeholder: "Enter package or invoice"
                    )
                ]
            )

        case "Business TV":
            return PaymentServiceConfig(
                name: service,
                providers: [
                    "DStv Business",
                    "Azam TV",
                    "Other Provider"
                ],
                fields: [
                    PaymentField(
                        id: "decoderNumber",
                        label: "Smartcard / Account Number",
                        placeholder: "Enter account number"
                    )
                ]
            )

        case "TRA Taxes":
            return PaymentServiceConfig(
                name: service,
                providers: ["TRA"],
                fields: [
                    PaymentField(
                        id: "taxType",
                        label: "Tax Type",
                        placeholder: "VAT, PAYE, WHT, CIT, etc."
                    ),
                    PaymentField(
                        id: "controlNumber",
                        label: "Control Number",
                        placeholder: "Enter control number"
                    ),
                    PaymentField(
                        id: "taxPeriod",
                        label: "Tax Period",
                        placeholder: "e.g. September 2026"
                    )
                ]
            )

        case "Suppliers":
            return PaymentServiceConfig(
                name: service,
                providers: [
                    "Saved Supplier",
                    "New Supplier"
                ],
                fields: [
                    PaymentField(
                        id: "supplierName",
                        label: "Supplier Name",
                        placeholder: "Enter supplier name"
                    ),
                    PaymentField(
                        id: "invoiceNumber",
                        label: "Invoice Number",
                        placeholder: "Enter invoice number"
                    )
                ]
            )

        default:
            return PaymentServiceConfig(
                name: service,
                providers: ["Other / Manual Entry"],
                fields: [
                    PaymentField(
                        id: "recipient",
                        label: "Recipient",
                        placeholder: "Enter recipient"
                    ),
                    PaymentField(
                        id: "reference",
                        label: "Reference",
                        placeholder: "Enter payment reference"
                    )
                ]
            )
        }
    }
}

struct PaymentField: Identifiable {
    let id: String
    let label: String
    let placeholder: String
}

