# OpenTelemetry Metrics Architecture & Implementation Plan

## 1. Overview & Goals

This document outlines the design and implementation roadmap for full OpenTelemetry Metrics support in `opentelemetry-dart`, aligned with the OpenTelemetry Specification (`v1.38+`).

### Core Objectives
1. Provide a clean, idiomatic Dart Metrics API complying with the OpenTelemetry Metrics API specification.
2. Provide a robust Metrics SDK implementation supporting standard aggregations (Sum, LastValue, ExplicitBucketHistogram, Drop).
3. Support both `Cumulative` and `Delta` aggregation temporalities.
4. Support the `View` mechanism for filtering attributes, renaming metric streams, and customizing aggregations.
5. Provide standard Readers (`MetricReader`, `PeriodicExportingMetricReader`).
6. Provide standard Exporters (`InMemoryMetricExporter`, `ConsoleMetricExporter`, and `OTLPMetricExporter` over HTTP/Protobuf).
7. Ensure full cross-platform compatibility across Dart VM, Flutter, and Web (`web_sdk.dart`).

---

## 2. Architecture & Data Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                              API Layer                                 │
│                                                                        │
│  MeterProvider ──> Meter ──> Instruments                               │
│                               ├── Sync: Counter, UpDownCounter,        │
│                               │         Histogram, Gauge               │
│                               └── Async: ObservableCounter,            │
│                                          ObservableUpDownCounter,      │
│                                          ObservableGauge               │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
┌──────────────────────────────────┼─────────────────────────────────────┐
│                              SDK Layer                                 │
│                                                                        │
│  MeterProvider                   ▼                                     │
│     │               InstrumentStorage (per View / Stream)              │
│     │                 ├── Aggregators (Sum, LastValue, Histogram, Drop)│
│     │                 ├── Temporality (Delta vs. Cumulative)           │
│     │                 └── Attributes normalizer & Cardinality Limit    │
│     ▼                                                                  │
│  Views System (View matches Instrument -> Stream / Aggregation)        │
│     │                                                                  │
│     ▼ (collect triggered)                                              │
│  MetricReader (e.g., PeriodicExportingMetricReader)                    │
│     ├── Evaluates Temporality Preferences                              │
│     └── Builds ResourceMetrics & ScopeMetrics                          │
│            │                                                           │
│            ▼                                                           │
│  MetricExporter (OTLP HTTP/Protobuf, InMemory, Console)                │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Public Seams & Interfaces

### 3.1 API Seam (`lib/src/api/metrics/` and `lib/api.dart`)
- **`MeterProvider`**:
  - `Meter get(String name, {String version, String schemaUrl, List<Attribute> attributes})`
- **`Meter`**:
  - Synchronous instrument factories:
    - `Counter<T extends num> createCounter<T extends num>(String name, {String? description, String? unit})`
    - `UpDownCounter<T extends num> createUpDownCounter<T extends num>(String name, {String? description, String? unit})`
    - `Histogram<T extends num> createHistogram<T extends num>(String name, {String? description, String? unit})`
    - `Gauge<T extends num> createGauge<T extends num>(String name, {String? description, String? unit})`
  - Asynchronous instrument factories:
    - `ObservableCounter<T extends num> createObservableCounter<T extends num>(String name, {void Function(Observer<T>)? callback, String? description, String? unit})`
    - `ObservableUpDownCounter<T extends num> createObservableUpDownCounter<T extends num>(String name, {void Function(Observer<T>)? callback, String? description, String? unit})`
    - `ObservableGauge<T extends num> createObservableGauge<T extends num>(String name, {void Function(Observer<T>)? callback, String? description, String? unit})`
  - Batch async callbacks: `void batchCallback(void Function(BatchObserver) callback, List<ObservableInstrument> instruments)`
- **Instruments**:
  - `Counter<T>`: `void add(T value, {List<Attribute>? attributes, Context? context})` (rejects `value < 0`)
  - `UpDownCounter<T>`: `void add(T value, {List<Attribute>? attributes, Context? context})`
  - `Histogram<T>`: `void record(T value, {List<Attribute>? attributes, Context? context})`
  - `Gauge<T>`: `void record(T value, {List<Attribute>? attributes, Context? context})`
  - `Observer<T>`: `void observe(T value, {List<Attribute>? attributes})`
- **Global Accessors** (`lib/src/api/open_telemetry.dart`):
  - `MeterProvider get globalMeterProvider`
  - `void registerGlobalMeterProvider(MeterProvider meterProvider)`

### 3.2 SDK Seam (`lib/src/sdk/metrics/` and `lib/sdk.dart`)
- **Aggregators**:
  - `SumAggregator`: Monotonic and non-monotonic numeric sum.
  - `LastValueAggregator`: Instantaneous sample point with timestamp.
  - `ExplicitBucketHistogramAggregator`: Count, sum, min, max, explicit bucket counts, default/custom boundaries.
  - `DropAggregator`: No-op aggregator for filtered metrics.
- **Temporality**:
  - `enum AggregationTemporality { cumulative, delta }`
  - Temporality conversion: Delta-to-Cumulative and Cumulative-to-Delta math per reader collection window.
- **Storage & Cardinality**:
  - `InstrumentStorage`: Maps normalized `AttributesKey` to aggregators.
  - Default cardinality limit (2,000 distinct attribute sets) with overflow attribute bucket (`otel.metric.overflow = true`).
- **Views**:
  - `class View`: Matches by instrument name, instrument type, meter name, version, schema URL.
  - Overrides: name, description, aggregation, attribute key filter.
- **MetricReader & Collection Pipeline**:
  - `abstract class MetricReader`: Defines `Future<void> collect()`, `shutdown()`, `forceFlush()`, and temporality selector.
  - `class PeriodicExportingMetricReader`: Dart `Timer`-based periodic collector.
- **Exporters**:
  - `abstract class MetricExporter`: `Future<ExportResult> export(List<ResourceMetrics> metrics)`
  - `InMemoryMetricExporter`: In-memory list of exported metrics for test assertions.
  - `ConsoleMetricExporter`: Human-readable output.
  - `OTLPMetricExporter`: HTTP POST with protobuf payload to `/v1/metrics`.

---

## 4. TDD Vertical Slice Strategy

Implementation will proceed in strict red-green cycles along pre-agreed seams:

- **Slice 1: Protobuf Generation & Serialization Base**
  - Generate Dart protobuf files for metrics from submodule `opentelemetry-proto`.
  - Verify protoc build cleanly and protobuf models are available.

- **Slice 2: Extended Metrics API & No-op Implementations**
  - Red: Tests verifying `UpDownCounter`, `Histogram`, `Gauge`, and async observables through `Meter` and `NoopMeterProvider`.
  - Red: Tests for `globalMeterProvider` and `registerGlobalMeterProvider`.
  - Green: Implement API interfaces, no-op classes, and global registration.

- **Slice 3: Core SDK Aggregators & Data Points**
  - Red: `SumAggregator` tests (monotonic rejection, cumulative/delta aggregation, int/double).
  - Green: Implement `SumAggregator`.
  - Red: `LastValueAggregator` tests (updates, timestamp tracking).
  - Green: Implement `LastValueAggregator`.
  - Red: `ExplicitBucketHistogramAggregator` tests (bucket index finding, sum/count/min/max tracking).
  - Green: Implement `ExplicitBucketHistogramAggregator`.

- **Slice 4: Instrument Storage, Attributes Normalization & Cardinality Overflow**
  - Red: Attributes normalization & hashing (`AttributesKey`).
  - Green: Implement `AttributesKey`.
  - Red: `InstrumentStorage` tests with cardinality limits (overflow bucket at max limit).
  - Green: Implement `InstrumentStorage`.

- **Slice 5: Views System**
  - Red: `View` criteria matching (exact and wildcard name, instrument kind, meter).
  - Green: Implement `View` and `ViewRegistry`.
  - Red: Attribute key filtering and aggregation override via View.
  - Green: Implement View transformations in storage creation.

- **Slice 6: MetricReader & Collection Pipeline**
  - Red: Async instrument callback collection during reader `collect()`.
  - Green: Wire observable instrument evaluation into `collect()`.
  - Red: `PeriodicExportingMetricReader` timer ticks, collect, flush, and shutdown.
  - Green: Implement `PeriodicExportingMetricReader`.

- **Slice 7: Metric Exporters & OTLP Serialization**
  - Red: `InMemoryMetricExporter` records exported batches.
  - Green: Implement `InMemoryMetricExporter`.
  - Red: Metric data to protobuf mapper (`ResourceMetrics`, `ScopeMetrics`, `Metric`, `DataPoint`).
  - Green: Implement `MetricDataToProtobuf` converter.
  - Red: `OTLPMetricExporter` HTTP request payload, headers, retry codes (429, 502, 503, 504).
  - Green: Implement `OTLPMetricExporter`.

- **Slice 8: End-to-End Integration & Public Export Surface**
  - Red: End-to-end integration test: `MeterProvider` -> Record metrics -> `PeriodicExportingMetricReader` / `collect()` -> `InMemoryMetricExporter` / `OTLPMetricExporter`.
  - Green: Final SDK wiring and exports in `lib/api.dart`, `lib/sdk.dart`, `lib/web_sdk.dart`.
  - Final verification: `dart analyze` and full test suite.
