import 'package:fl_query/src/core/query.dart';
import 'package:fl_query/src/core/query_key.dart';
import 'package:fl_query/src/core/retryer.dart';

typedef QueryMeta<T> = Map<String, T>;
typedef QueryKeyHashFunction = String Function(QueryKey queryKey);
typedef QueryFunction<T, TPageParam> = Function(QueryFunctionContext context);
typedef GetPreviousPageParamFunction<TQueryFnData> = Function(
  TQueryFnData firstPage,
  List<TQueryFnData> allPages,
);
typedef GetNextPageParamFunction<TQueryFnData> = Function(
  TQueryFnData firstPage,
  List<TQueryFnData> allPages,
);

class QueryOptions<TQueryFnData, TError, TData> {
  ShouldRetryFunction<TError>? retry;
  RetryDelayFunction<TError>? retryDelay;
  Duration? cacheTime;
  bool Function(TData? oldData, TData newData)? isDataEqual;
  QueryFunction? queryFn;
  QueryKey? queryKey;

  /// Basically [QueryKey.key] in short form
  String? queryHash;
  QueryKeyHashFunction? queryKeyHashFn;
  TData? initialData;
  DateTime? initialDataUpdatedAt;
  QueryBehavior<TQueryFnData, TError, TData>? behavior;

  /// Set this to `false` to disable structural sharing between query  results\
  /// Defaults to `true`.
  bool? structuralSharing;

  /// This function can be set to automatically get the previous cursor for infinite queries.
  /// The result will also be used to determine the value of `hasPreviousPage`.
  GetPreviousPageParamFunction<TQueryFnData>? getPreviousPageParam;

  /// This function can be set to automatically get the next cursor for
  /// infinite queries.
  /// The result will also be used to determine the value of
  /// `hasNextPage`.
  GetNextPageParamFunction<TQueryFnData>? getNextPageParam;
  bool? defaulted;

  /// Additional payload to be stored on each query.
  /// Use this property to pass information that can be used in other places.
  QueryMeta? meta;

  QueryOptions({
    this.retry,
    this.retryDelay,
    this.queryKey,
    this.queryKeyHashFn,
    this.cacheTime,
    this.isDataEqual,
    this.queryFn,
    this.defaulted,
    this.initialData,
    this.initialDataUpdatedAt,
    this.meta,
    this.queryHash,
    this.structuralSharing,
    this.getPreviousPageParam,
    this.getNextPageParam,
  });

  QueryOptions.fromJson(Map<String, dynamic> json) {
    queryKey = json["queryKey"];
    queryKeyHashFn = json["queryKeyHashFn"];
    cacheTime = json["cacheTime"];
    isDataEqual = json["isDataEqual"];
    queryFn = json["queryFn"];
    queryHash = json["queryHash"];
    initialData = json["initialData"];
    initialDataUpdatedAt = json["initialDataUpdatedAt"];
    meta = json["meta"];
    structuralSharing = json["structuralSharing"];
    defaulted = json["defaulted"];
    retry = json["retry"];
    retryDelay = json["retryDelay"];
    behavior = json["behavior"];
    getPreviousPageParam = json["getPreviousPageParam"];
    getNextPageParam = json["getNextPageParam"];
  }

  Map<String, dynamic> toJson() {
    return {
      "queryKey": queryKey,
      "queryKeyHashFn": queryKeyHashFn,
      "cacheTime": cacheTime,
      "isDataEqual": isDataEqual,
      "queryFn": queryFn,
      "queryHash": queryHash,
      "initialData": initialData,
      "initialDataUpdatedAt": initialDataUpdatedAt,
      "meta": meta,
      "structuralSharing": structuralSharing,
      "defaulted": defaulted,
      "retry": retry,
      "retryDelay": retryDelay,
      "behavior": behavior,
      "getPreviousPageParam": getPreviousPageParam,
      "getNextPageParam": getNextPageParam,
    };
  }
}

class QueryFilters {
  bool? active;
  bool? exact;
  bool? inactive;
  bool Function(Query query)? predicate;
  bool? queryKey;
  bool? stale;
  bool? fetching;

  QueryFilters({
    this.active,
    this.exact,
    this.inactive,
    this.predicate,
    this.queryKey,
    this.stale,
    this.fetching,
  });

  Map<String, dynamic> toJson() {
    return {
      "active": active,
      "exact": exact,
      "inactive": inactive,
      "queryKey": queryKey,
      "stale": stale,
      "fetching": fetching,
      "predicate": predicate,
    };
  }
}

class RefetchPageFilters<TPageData> {
  bool Function(TPageData lastPage, int index, List<TPageData> allPages)?
      refetchPage;
}

class RefetchQueryFilters<TPageData>
    implements QueryFilters, RefetchPageFilters<TPageData> {
  @override
  bool? active;
  @override
  bool? exact;
  @override
  bool? fetching;
  @override
  bool? inactive;
  @override
  bool Function(Query query)? predicate;
  @override
  bool? queryKey;
  @override
  bool Function(TPageData lastPage, int index, List<TPageData> allPages)?
      refetchPage;
  @override
  bool? stale;

  RefetchQueryFilters({
    this.active,
    this.exact,
    this.inactive,
    this.predicate,
    this.queryKey,
    this.stale,
    this.fetching,
    this.refetchPage,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      "active": active,
      "exact": exact,
      "inactive": inactive,
      "queryKey": queryKey,
      "stale": stale,
      "fetching": fetching,
      "predicate": predicate,
    };
  }
}

class ResultOptions {
  bool? throwOnError;
}

class RefetchOptions implements ResultOptions {
  bool? cancelRefetch;

  @override
  bool? throwOnError;
}

enum QueryStatus {
  idle,
  loading,
  error,
  success,
}

class QueryObserverResult<TData, TError> {
  TData? data;
  DateTime? dataUpdatedAt;
  TError? error;
  DateTime? errorUpdatedAt;
  int failureCount;
  bool isError;
  bool isFetched;
  bool isFetchedAfterMount;
  bool isFetching;
  bool isIdle;
  bool isLoading;
  bool isLoadingError;
  bool isPlaceholderData;
  bool isPreviousData;
  bool isRefetchError;
  bool isRefetching;
  bool isStale;
  bool isSuccess;
  Future<QueryObserverResult<TData, TError>> Function<TPageData>({
    RefetchOptions options,
    RefetchQueryFilters<TPageData> filters,
  }) refetch;
  void Function() remove;
  QueryStatus status;

  QueryObserverResult({
    required this.failureCount,
    required this.isError,
    required this.isFetched,
    required this.isFetchedAfterMount,
    required this.isFetching,
    required this.isIdle,
    required this.isLoading,
    required this.isLoadingError,
    required this.isPlaceholderData,
    required this.isPreviousData,
    required this.isRefetchError,
    required this.isRefetching,
    required this.isStale,
    required this.isSuccess,
    required this.refetch,
    required this.remove,
    required this.status,
    this.data,
    this.error,
    this.dataUpdatedAt,
    this.errorUpdatedAt,
  }) {
    String errorLabel =
        "[QueryObserverResult.QueryObserverResult] status = `$status` but parent has wrong set of properties";
    if (status == QueryStatus.idle &&
        (data != null ||
            error != null ||
            isError ||
            !isIdle ||
            isLoading ||
            isLoadingError ||
            isRefetchError ||
            isSuccess)) throw Exception(errorLabel);

    if (status == QueryStatus.loading &&
        (data != null ||
            error != null ||
            isError ||
            isIdle ||
            !isLoading ||
            isLoadingError ||
            isRefetchError ||
            isSuccess != false)) throw Exception(errorLabel);

    if (status == QueryStatus.error &&
        ((!(error is TError)) || !isError || isIdle || isLoading || isSuccess))
      throw Exception(errorLabel);

    if (status == QueryStatus.success &&
        (!(data is TData) ||
            error != null ||
            isError ||
            isIdle ||
            isLoading ||
            isLoadingError ||
            isRefetchError ||
            !isSuccess)) throw Exception(errorLabel);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'data': this.data,
      'dataUpdatedAt': dataUpdatedAt,
      'error': error,
      'errorUpdatedAt': errorUpdatedAt,
      'failureCount': failureCount,
      'isError': isError,
      'isFetched': isFetched,
      'isFetchedAfterMount': isFetchedAfterMount,
      'isFetching': isFetching,
      'isIdle': isIdle,
      'isLoading': isLoading,
      'isLoadingError': isLoadingError,
      'isPlaceholderData': isPlaceholderData,
      'isPreviousData': isPreviousData,
      'isRefetchError': isRefetchError,
      'isRefetching': isRefetching,
      'isStale': isStale,
      'isSuccess': isSuccess,
      'refetch': refetch,
      'remove': remove,
      'status': status,
    };
    return data;
  }
}

typedef RefetchIntervalFunction<TQueryFnData, TError, TQueryData, TData>
    = Duration? Function(
  TData? data,
  Query<TQueryFnData, TError, TQueryData> query,
);

enum RefetchOnReconnect {
  on,
  off,
  always,
}

enum RefetchOnMount {
  on,
  off,
  always,
}

class QueryObserverOptions<TQueryFnData, TError, TData, TQueryData>
    extends QueryOptions<TQueryFnData, TError, TQueryData> {
  bool? enabled;
  Duration? staleTime;
  RefetchIntervalFunction<TQueryFnData, TError, TQueryData, TData>?
      refetchInterval;
  bool? refetchIntervalInBackground;
  RefetchOnReconnect? refetchOnReconnect;
  RefetchOnMount? refetchOnMount;
  bool? retryOnMount;
  OnData? onSuccess;
  OnError? onError;
  void Function(TData? data, [TError? error])? onSettled;
  bool Function(TError error)? useErrorBoundary;
  TData Function(TQueryData? data)? select;
  bool? suspense;
  bool? keepPreviousData;
  TQueryData? placeholderData;
  bool? optimisticResults;
  /*List<String>|'tracked'?*/ dynamic notifyOnChangeProps;
  List<String>? notifyOnChangePropsExclusions;

  QueryObserverOptions({
    this.enabled,
    this.staleTime,
    this.refetchInterval,
    this.refetchIntervalInBackground,
    this.refetchOnReconnect,
    this.refetchOnMount,
    this.retryOnMount,
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.useErrorBoundary,
    this.select,
    this.suspense,
    this.keepPreviousData,
    this.placeholderData,
    this.optimisticResults,
    QueryKey? queryKey,
    QueryKeyHashFunction? queryKeyHashFn,
    Duration? cacheTime,
    bool Function(TQueryData? oldData, TQueryData newData)? isDataEqual,
    QueryFunction? queryFn,
    String? queryHash,
    TQueryData? initialData,
    DateTime? initialDataUpdatedAt,
    QueryMeta? meta,
    bool? structuralSharing,
    bool? defaulted,
  }) : super(
          queryKey: queryKey,
          queryKeyHashFn: queryKeyHashFn,
          cacheTime: cacheTime,
          isDataEqual: isDataEqual,
          queryFn: queryFn,
          queryHash: queryHash,
          initialData: initialData,
          initialDataUpdatedAt: initialDataUpdatedAt,
          meta: meta,
          structuralSharing: structuralSharing,
          defaulted: defaulted,
        );
}

class QueryFunctionContext<TPageParam> {
  QueryKey queryKey;
  /* AbortSignal */ dynamic? signal;
  TPageParam? pageParam;
  QueryMeta? meta;

  QueryFunctionContext({
    required this.queryKey,
    this.signal,
    this.pageParam,
    this.meta,
  });
}