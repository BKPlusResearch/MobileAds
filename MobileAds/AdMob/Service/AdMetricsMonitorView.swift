//
//  AdMetricsMonitorView.swift
//  MobileAds
//
//  Created by Claude on 11/3/26.
//

import UIKit

/// Debug overlay that displays ad metrics in a table layout, similar to the AdMob dashboard.
/// Shows: Ad Unit | Type | Req | Match% | Show% | Imp | CTR% | Clicks
@MainActor
final class AdMetricsMonitorView: UIView {

    // MARK: - UI Elements

    private let containerView = UIView()
    private let titleBar = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let resetButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let emptyLabel = UILabel()
    private let sessionLabel = UILabel()

    /// Auto-refresh timer
    private var refreshTimer: Timer?

    /// Session start time for display
    private let sessionStartTime = Date()

    // MARK: - Callbacks

    var onClose: (() -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        startAutoRefresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.85)

        // Container
        containerView.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        addSubview(containerView)

        // Title Bar
        titleBar.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        containerView.addSubview(titleBar)

        // Title
        titleLabel.text = "📊 Ad Metrics Monitor"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleBar.addSubview(titleLabel)

        // Session duration label
        sessionLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        sessionLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        titleBar.addSubview(sessionLabel)

        // Close Button
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        titleBar.addSubview(closeButton)

        // Reset Button
        resetButton.setTitle("Reset", for: .normal)
        resetButton.setTitleColor(UIColor(red: 1.0, green: 0.45, blue: 0.45, alpha: 1.0), for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        titleBar.addSubview(resetButton)

        // ScrollView
        scrollView.showsVerticalScrollIndicator = true
        scrollView.indicatorStyle = .white
        containerView.addSubview(scrollView)

        // StackView (holds header + rows)
        stackView.axis = .vertical
        stackView.spacing = 0
        scrollView.addSubview(stackView)

        // Empty state
        emptyLabel.text = "No ad requests yet.\nLoad some ads and check back."
        emptyLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        scrollView.addSubview(emptyLabel)

        setupConstraints()
        refreshData()
    }

    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        sessionLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Container - centered with padding
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            containerView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            containerView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),

            // Title Bar
            titleBar.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 48),

            // Title Label
            titleLabel.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            // Session Label
            sessionLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            sessionLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            // Close Button
            closeButton.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            // Reset Button
            resetButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            resetButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            // ScrollView
            scrollView.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // StackView
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Empty label
            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.leadingAnchor, constant: 20),
        ])
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func resetTapped() {
        AdMetricsTracker.shared.reset()
        refreshData()
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshData()
            }
        }
    }

    // MARK: - Data Refresh

    func refreshData() {
        // Update session duration
        let elapsed = Int(Date().timeIntervalSince(sessionStartTime))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        sessionLabel.text = String(format: "(%02d:%02d)", minutes, seconds)

        let allMetrics = AdMetricsTracker.shared.getAllMetrics()

        // Clear existing rows
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if allMetrics.isEmpty {
            emptyLabel.isHidden = false
            return
        }

        emptyLabel.isHidden = true

        // Add header
        stackView.addArrangedSubview(createHeaderRow())

        // Add separator
        stackView.addArrangedSubview(createSeparator())

        // Add data rows
        for (index, metric) in allMetrics.enumerated() {
            let row = createDataRow(metric: metric, isAlternate: index % 2 == 1)
            stackView.addArrangedSubview(row)
        }

        // Add summary row
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(createSummaryRow(allMetrics))
    }

    // MARK: - Row Builders

    private func createHeaderRow() -> UIView {
        let columns = ["Ad Unit", "Type", "Req", "Match%", "Show%", "Imp", "CTR%", "Click"]
        return createRow(values: columns, isHeader: true)
    }

    private func createDataRow(metric: AdMetrics, isAlternate: Bool) -> UIView {
        // Shorten ad unit name for display
        let shortName = shortenAdUnit(metric.adUnit)

        let values: [String] = [
            shortName,
            metric.adType.rawValue.prefix(5).uppercased(),
            "\(metric.requestCount)",
            String(format: "%.0f%%", metric.matchRate),
            String(format: "%.0f%%", metric.showRate),
            "\(metric.impressionCount)",
            String(format: "%.1f%%", metric.ctr),
            "\(metric.clickCount)"
        ]

        let row = createRow(values: values, isHeader: false)

        if isAlternate {
            row.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        }

        // Highlight low show rate in red
        if metric.loadedCount > 0 && metric.showRate < 60 {
            row.backgroundColor = UIColor(red: 0.3, green: 0.1, blue: 0.1, alpha: 1.0)
        }

        return row
    }

    private func createSummaryRow(_ metrics: [AdMetrics]) -> UIView {
        let totalReq = metrics.reduce(0) { $0 + $1.requestCount }
        let totalLoaded = metrics.reduce(0) { $0 + $1.loadedCount }
        let totalImp = metrics.reduce(0) { $0 + $1.impressionCount }
        let totalClick = metrics.reduce(0) { $0 + $1.clickCount }

        let avgMatch = totalReq > 0 ? Double(totalLoaded) / Double(totalReq) * 100 : 0
        let avgShow = totalLoaded > 0 ? Double(totalImp) / Double(totalLoaded) * 100 : 0
        let avgCTR = totalImp > 0 ? Double(totalClick) / Double(totalImp) * 100 : 0

        let values: [String] = [
            "TOTAL",
            "—",
            "\(totalReq)",
            String(format: "%.0f%%", avgMatch),
            String(format: "%.0f%%", avgShow),
            "\(totalImp)",
            String(format: "%.1f%%", avgCTR),
            "\(totalClick)"
        ]

        let row = createRow(values: values, isHeader: false)
        row.backgroundColor = UIColor(white: 0.2, alpha: 1.0)

        // Bold all labels in summary
        for subview in row.subviews {
            if let label = subview as? UILabel {
                label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
                label.textColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
            }
        }

        return row
    }

    private func createRow(values: [String], isHeader: Bool) -> UIView {
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: isHeader ? 32 : 36).isActive = true

        // Column widths (proportional)
        // Ad Unit gets more space, others are equal
        let columnWidths: [CGFloat] = [0.28, 0.10, 0.08, 0.12, 0.12, 0.08, 0.12, 0.10]

        var previousAnchor = row.leadingAnchor

        for (i, value) in values.enumerated() {
            let label = UILabel()
            label.text = value
            label.textAlignment = i == 0 ? .left : .center
            label.lineBreakMode = .byTruncatingMiddle

            if isHeader {
                label.font = .systemFont(ofSize: 10, weight: .semibold)
                label.textColor = UIColor(white: 0.6, alpha: 1.0)
            } else {
                label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                label.textColor = .white
            }

            row.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: row.topAnchor),
                label.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                label.leadingAnchor.constraint(equalTo: previousAnchor, constant: i == 0 ? 8 : 2),
                label.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: columnWidths[i], constant: -4),
            ])

            previousAnchor = label.trailingAnchor
        }

        return row
    }

    private func createSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return sep
    }

    // MARK: - Helpers

    /// Shorten ad unit ID for display (e.g. "ca-app-pub-xxx/12345" → "…/12345")
    private func shortenAdUnit(_ adUnit: String) -> String {
        if let slashIndex = adUnit.lastIndex(of: "/") {
            let suffix = adUnit[adUnit.index(after: slashIndex)...]
            return "…/\(suffix)"
        }
        // If no slash, take last 10 chars
        if adUnit.count > 12 {
            return "…\(adUnit.suffix(10))"
        }
        return adUnit
    }
}
