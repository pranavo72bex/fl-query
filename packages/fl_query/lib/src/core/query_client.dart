import 'package:fl_query/src/core/models.dart';
import 'package:fl_query/src/core/notify_manager.dart';
import 'package:fl_query/src/core/online_manager.dart';
import 'package:fl_query/src/core/query.dart';
import 'package:fl_query/src/core/query_cache.dart';
import 'package:fl_query/src/core/query_key.dart';
import 'package:fl_query/src/core/query_observer.dart';
import 'package:fl_query/src/core/utils.dart';
import 'package:collection/collection.dart';

class QueryDefaults {
  QueryKey queryKey;
  QueryOptions defaultOptions;
  QueryDefaults({
    required this.queryKey,
    required this.defaultOptions,
  });
}

class MutationDefaults {
  // QueryKey queryKey;
  // QueryOptions defaultOptions;
  // MutationDefaults({
  //   required this.queryKey,
  //   required this.defaultOptions,
  // });
}

class QueryData<TData extends Map<String, dynamic>> {
  QueryKey queryKey;
  TData data;
  QueryData({
    required this.queryKey,
    required this.data,
  });
}

class QueryClient {
  QueryCache _queryCache;
  // QueryCache _mutationCache;
  DefaultOptions _defaultOptions;
  List<QueryDefaults> _queryDefaults;
  // List<MutationDefaults> _mutationDefaults;
  void Function()? _unsubscribeFocus;
  void Function()? _unsubscribeOnline;
  // MutationKey _mutationKey;
  // MutationOptions<any, any, any, any> _mutationDefaultOptions;

  QueryClient({
    QueryCache? queryCache,
    QueryCache? mutationCache,
    DefaultOptions? defaultOptions,
  })  : _queryCache = queryCache ?? QueryCache(),
        _defaultOptions = defaultOptions ?? DefaultOptions(),
        _queryDefaults = [];
  /* _mutationDefaults = [], */
  /* _mutationCache = mutationCache ?? QueryCache() */

  void mount() {
    // this.unsubscribeFocus = focusManager.subscribe(() => {
    //   if (focusManager.isFocused() && onlineManager.isOnline()) {
    //     this.mutationCache.onFocus()
    //     this.queryCache.onFocus()
    //   }
    // })
    _unsubscribeOnline = onlineManager.subscribe(() async {
      if (/* focusManager.isFocused() && */ await onlineManager.isOnline()) {
        // _mutationCache.onOnline();
        _queryCache.onOnline();
      }
    });
  }

  void unmount() {
    _unsubscribeFocus?.call();
    _unsubscribeOnline?.call();
  }

  int isFetching({QueryKey? queryKey, QueryFilters? filters}) {
    filters?.fetching = true;
    return _queryCache.findAll(null, filters).length;
  }

  // int isMutating([MutationFilters? filters]) {
  //   return _mutationCache.findAll({ ...filters, fetching: true }).length
  // }

  TData? getQueryData<TData extends Map<String, dynamic>>(
    QueryKey queryKey, [
    QueryFilters? filters,
  ]) {
    return _queryCache
        .find<TData, dynamic, Map<String, dynamic>>(
            queryKey, filters ?? QueryFilters())
        ?.state
        .data as TData?;
  }

  List<QueryData<TData>> getQueriesData<TData extends Map<String, dynamic>>({
    QueryKey? queryKeys,
    QueryFilters? filters,
  }) {
    return getQueryCache().findAll(queryKeys, filters).map((query) {
      return QueryData<TData>(
        data: query.state.data as TData,
        queryKey: query.queryKey,
      );
    }).toList();
  }

  TData setQueryData<TData extends Map<String, dynamic>>(
    QueryKey queryKey,
    DataUpdateFunction<TData?, TData> updater, [
    DateTime? updatedAt,
  ]) {
    final QueryOptions<Map<String, dynamic>, dynamic, TData> defaultedOptions =
        QueryOptions<Map<String, dynamic>, dynamic, TData>.fromJson(
            defaultQueryOptions<Map<String, dynamic>, dynamic, TData,
                        Map<String, dynamic>>(
                    QueryObserverOptions<Map<String, dynamic>, dynamic, TData,
                        Map<String, dynamic>>(queryKey: queryKey))
                .toJson());
    return _queryCache
        .build<Map<String, dynamic>, dynamic, TData>(this, defaultedOptions)
        .setData(
          updater,
          updatedAt: updatedAt,
        );
  }

  List<QueryData> setQueriesData<TData extends Map<String, dynamic>>({
    required DataUpdateFunction<TData?, TData> updater,
    QueryKey? queryKeys,
    QueryFilters? filters,
    DateTime? updatedAt,
  }) {
    if (queryKeys == null && filters == null)
      throw Exception(
          "[QueryClient.setQueriesData] both `queryKey` & `filters` can't be null at the same time");
    return notifyManager
        .batch(() => getQueryCache().findAll(queryKeys, filters).map(
              (query) => QueryData(
                queryKey: query.queryKey,
                data: setQueryData<TData>(
                  query.queryKey,
                  updater,
                  updatedAt,
                ),
              ),
            ))
        .toList();
  }

  QueryState<TData, TError>?
      getQueryState<TData extends Map<String, dynamic>, TError>(
    QueryKey queryKey, [
    QueryFilters? filters,
  ]) {
    return _queryCache
        .find<TData, TError, Map<String, dynamic>>(
          queryKey,
          filters ?? QueryFilters(),
        )
        ?.state as QueryState<TData, TError>?;
  }

  void removeQueries({QueryKey? queryKeys, QueryFilters? filters}) {
    notifyManager.batch(
      () => {
        _queryCache.findAll(queryKeys, filters).forEach((query) {
          _queryCache.remove(query);
        })
      },
    );
  }

  Future<void> resetQueries<TPageData>({
    QueryKey? queryKeys,
    RefetchableQueryFilters<TPageData>? filters,
    bool? throwOnError,
  }) {
    filters?.active = true;
    var refetchFilters = RefetchableQueryFilters<TPageData>.fromJson({
      ...(filters?.toJson() ?? {}),
      "active": true,
    });

    return notifyManager.batch(() {
      _queryCache.findAll(queryKeys, filters).forEach((query) {
        query.reset();
      });
      return refetchQueries(
        filters: refetchFilters,
        options: RefetchOptions(throwOnError: throwOnError),
      );
    });
  }

  Future<void> cancelQueries({
    QueryKey? queryKeys,
    QueryFilters? filters,
    bool? revert = true,
    bool? silent,
  }) {
    var futures = notifyManager.batch(() =>
        _queryCache.findAll(queryKeys, filters).map((query) => query.cancel(
              revert: revert,
              silent: silent,
            )));
    return Future.wait(futures).then(noop).catchError(noop);
  }

  Future<void> invalidateQueries<TPageData>({
    QueryKey? queryKeys,
    InvalidateQueryFilters<TPageData>? filters,
    RefetchOptions? options,
  }) {
    var refetchFilters = RefetchableQueryFilters<TPageData>.fromJson({
      ...(filters?.toJson() ?? {}),
      // if filters.refetchActive is not provided and filters.active is explicitly false,
      // e.g. invalidateQueries({ active: false }), we don't want to refetch active queries
      "active": filters?.refetchActive ?? filters?.active ?? true,
      "inactive": filters?.refetchInactive ?? false,
    });
    return notifyManager.batch(() {
      _queryCache.findAll(queryKeys, filters).forEach((query) {
        query.invalidate();
      });
      return this.refetchQueries(
        filters: refetchFilters,
        options: options,
      );
    });
  }

  Future<void> refetchQueries<TPageData>({
    QueryKey? queryKeys,
    RefetchableQueryFilters<TPageData>? filters,
    RefetchOptions? options,
  }) {
    var futures = notifyManager.batch(
      () => _queryCache.findAll(queryKeys, filters).map(
            (query) => query.fetch(
              null,
              ObserverFetchOptions(
                cancelRefetch: options?.cancelRefetch,
                throwOnError: options?.throwOnError,
                meta: {"refetchPage": filters?.refetchPage},
              ),
            ),
          ),
    );

    var future = Future.wait(futures).then(noop);

    if (options?.throwOnError == false) {
      future = future.catchError(noop);
    }

    return future;
  }

  Future<TData> fetchQuery<TQueryFnData extends Map<String, dynamic>, TError,
      TData extends Map<String, dynamic>>({
    QueryKey? queryKey,
    QueryFunction<TQueryFnData, dynamic>? queryFn,
    FetchQueryOptions<TQueryFnData, TError, TData>? options,
  }) {
    var defaultedOptions = this.defaultQueryOptions(
      QueryObserverOptions<Map<String, dynamic>, dynamic, Map<String, dynamic>,
          TData>(
        queryFn: queryFn,
        queryKey: queryKey,
        staleTime: options?.staleTime,
        cacheTime: options?.cacheTime,
        defaulted: options?.defaulted,
        initialData: options?.initialData,
        initialDataUpdatedAt: options?.initialDataUpdatedAt,
        isDataEqual: options?.isDataEqual,
        meta: options?.meta,
        queryHash: options?.queryHash,
        queryKeyHashFn: options?.queryKeyHashFn,
        structuralSharing: options?.structuralSharing,
      ),
    );
    // returning 0 indicates turing off retry
    defaultedOptions.retry ??= (_, __) => 0;
    var query = _queryCache.build<Map<String, dynamic>, dynamic, TData>(
        this, defaultedOptions);
    return query.isStaleByTime(defaultedOptions.staleTime)
        ? query.fetch(defaultedOptions)
        : Future.value(query.state.data as TData);
  }

  Future<void> prefetchQuery<TQueryFnData extends Map<String, dynamic>, TError,
      TData extends Map<String, dynamic>>({
    QueryKey? queryKey,
    QueryFunction<TQueryFnData, dynamic>? queryFn,
    FetchQueryOptions<TQueryFnData, TError, TData>? options,
  }) {
    return fetchQuery<TQueryFnData, dynamic, TData>(
      queryKey: queryKey,
      queryFn: queryFn,
      options: options,
    ).then(noop).catchError(noop);
  }

  QueryObserverOptions<TQueryFnData, TError, TData,
      TQueryData> defaultQueryOptions<
          TQueryFnData extends Map<String, dynamic>,
          TError,
          TData extends Map<String, dynamic>,
          TQueryData extends Map<String, dynamic>>(
      QueryObserverOptions<TQueryFnData, TError, TData, TQueryData>? options) {
    if (options?.defaulted == true) return options!;
    var defaultedOptions =
        QueryObserverOptions<TQueryFnData, TError, TData, TQueryData>.fromJson({
      ...(_defaultOptions.queries?.toJson() ?? {}),
      ...(getQueryDefaults(options?.queryKey)?.toJson() ?? {}),
      ...(options?.toJson() ?? {}),
      "defaulted": true,
    });
    if (defaultedOptions.queryHash == null &&
        defaultedOptions.queryKey != null) {
      defaultedOptions.queryHash = hashQueryKeyByOptions(
        defaultedOptions.queryKey!,
        defaultedOptions,
      );
    }

    return defaultedOptions;
  }

  QueryObserverOptions<TQueryFnData, TError, TData, TQueryData>
      defaultQueryObserverOptions<
          TQueryFnData extends Map<String, dynamic>,
          TError,
          TData extends Map<String, dynamic>,
          TQueryData extends Map<String, dynamic>>([
    QueryObserverOptions<TQueryFnData, TError, TData, TQueryData>? options,
  ]) {
    return this.defaultQueryOptions(options);
  }

  DefaultOptions getDefaultOptions() {
    return _defaultOptions;
  }

  void setDefaultOptions(DefaultOptions options) {
    _defaultOptions = options;
  }

  QueryObserverOptions? getQueryDefaults([QueryKey? queryKey]) {
    return queryKey != null
        ? QueryObserverOptions.fromJson((_queryDefaults
                    .firstWhereOrNull(
                      (x) => queryKey.key == x.queryKey.key,
                    )
                    ?.defaultOptions)
                ?.toJson() ??
            {})
        : null;
  }

  void setQueryDefaults(QueryKey queryKey, QueryObserverOptions options) {
    var result = _queryDefaults.firstWhereOrNull(
      (x) => queryKey.key == x.queryKey.key,
    );

    if (result != null) {
      result.defaultOptions = options;
    } else {
      _queryDefaults
          .add(QueryDefaults(queryKey: queryKey, defaultOptions: options));
    }
  }

  // getMutationDefaults() {}
  // setMutationDefaults() {}
  // getMutationCache() {}

  QueryCache getQueryCache() {
    return _queryCache;
  }

  void clear() {
    _queryCache.clear();
    // _mutationCache.clear();
  }
}
