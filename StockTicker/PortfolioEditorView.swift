import SwiftUI

struct PortfolioEditorView: View {
    @ObservedObject var vm: TickerViewModel
    @Binding var isPresented: Bool

    @State private var newSymbol: String = ""
    @State private var inputError: String? = nil
    @State private var isValidating: Bool = false
    @FocusState private var inputFocused: Bool

    // Ticker gradient colors — match the dark bar aesthetic
    private let gradientStart = Color(red: 0.13, green: 0.53, blue: 0.95)   // electric blue
    private let gradientMid   = Color(red: 0.45, green: 0.28, blue: 0.92)   // violet
    private let gradientEnd   = Color(red: 0.08, green: 0.72, blue: 0.55)   // teal

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.11))
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                Divider()
                    .background(Color.white.opacity(0.08))

                // ── Symbol List ───────────────────────────────────────────
                symbolList
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.top, 8)

                // ── Add Symbol Input ──────────────────────────────────────
                addSymbolInput
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                // ── Apply Button ──────────────────────────────────────────
                applyButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 340, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 10)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Portfolio")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [gradientStart, gradientMid, gradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("\(vm.symbols.count) symbol\(vm.symbols.count == 1 ? "" : "s") tracked")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Symbol List

    private var symbolList: some View {
        List {
            ForEach(vm.symbols, id: \.self) { symbol in
                HStack(spacing: 12) {
                    // Gradient accent bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [gradientStart, gradientEnd],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3, height: 20)

                    Text(symbol)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)

                    Spacer()

                    // Live price if available
                    if let quote = vm.quotes[symbol] {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "$%.2f", quote.currentPrice))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.7))
                            Text(String(format: "%@%.2f%%",
                                        quote.isPositive ? "+" : "",
                                        quote.changePercent))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(quote.isPositive
                                    ? Color(red: 0.2, green: 0.85, blue: 0.45)
                                    : Color(red: 1.0, green: 0.35, blue: 0.35))
                        }
                    }

                    // Remove button
                    Button(action: { vm.removeSymbol(symbol) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.white.opacity(0.2))
                            .help("Remove \(symbol)")
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        // highlight on hover handled by SwiftUI automatically
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onMove { from, to in
                vm.moveSymbols(from: from, to: to)
            }
            .onDelete { offsets in
                offsets.forEach { vm.removeSymbol(vm.symbols[$0]) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxHeight: 260)
    }

    // MARK: - Add Symbol Input

    private var addSymbolInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Text field with gradient border when focused
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            inputFocused
                            ? LinearGradient(colors: [gradientStart, gradientMid, gradientEnd],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)],
                                             startPoint: .leading, endPoint: .trailing),
                            lineWidth: inputFocused ? 1.5 : 0.5
                        )

                    TextField("Add ticker  e.g. NVDA", text: $newSymbol)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)
                        .focused($inputFocused)
                        .padding(.horizontal, 12)
                        .onSubmit { addCurrentSymbol() }
                        .onChange(of: newSymbol) { _, newValue in
                            inputError = nil
                            newSymbol = newValue.uppercased()
                        }
                }
                .frame(height: 38)

                // Add button — gradient pill
                Button(action: addCurrentSymbol) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [gradientStart, gradientMid],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .disabled(newSymbol.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
            }

            if let error = inputError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 11))
                }
                .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.35))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: inputError)
    }

    // MARK: - Apply Button

    private var applyButton: some View {
        Button(action: {
            vm.reloadAfterEdit()
            isPresented = false
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [gradientStart, gradientMid, gradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                // Subtle shimmer overlay
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Apply & Refresh")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(height: 42)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func addCurrentSymbol() {
        let sym = newSymbol.uppercased().trimmingCharacters(in: .whitespaces)
        guard !sym.isEmpty else { return }

        if vm.symbols.contains(sym) {
            inputError = "\(sym) is already in your portfolio"
            return
        }
        if vm.symbols.count >= 10 {
            inputError = "Maximum 10 symbols allowed"
            return
        }
        if sym.count > 6 {
            inputError = "Ticker symbols are 1–5 characters"
            return
        }

        vm.addSymbol(sym)
        newSymbol = ""
        inputError = nil
    }
}
