import 'package:fl_query/src/core/models.dart';
import 'package:fl_query/src/core/notify_manager.dart';
import 'package:fl_query/src/core/query.dart';
import 'package:fl_query/src/core/query_client.dart';
import 'package:fl_query/src/core/query_key.dart';
import 'package:fl_query/src/core/subscribable.dart';
import 'package:fl_query/src/core/utils.dart';
import 'package:collection/collection.dart';

enum QueryCacheNotifyEventType {
  observerResultsUpdated,
  observerRemoved,
  observerAdded,
  queryUpdated,
  queryRemoved,
  queryAdded
}

class QueryCacheNotifyEvent {
  Query query;
  Object? observer;
  Object? action;
  QueryCacheNotifyEventType type;
  QueryCacheNotifyEvent(
    this.type,
    this.query, {
    this.observer,
    this.action,
  }) {
    if ([
          QueryCacheNotifyEventType.observerAdded,
          QueryCacheNotifyEventType.observerRemoved
        ].contains(type) &&
        observer == null)
      throw Exception(
          "[QueryCacheNotifyEvent.constructor] property `observer` can't be `null` for `QueryCacheNotifyEventType.observerAdded` & `QueryCacheNotifyEventType.observerRemoved`");
    if (type == QueryCacheNotifyEventType.queryUpdated && action == null)
      throw Exception(
          "[QueryCacheNotifyEvent.constructor] property `action` can't be `null` for `QueryCacheNotifyEventType.queryUpdated`");
  }
}

typedef QueryCacheListener = void Function(QueryCacheNotifyEvent? event);
typedef QueryCacheOnError = void Function(dynamic error, Query query);
typedef QueryCacheOnData = void Function(dynamic data, Query query);
typedef QueryHashMap = Map<String, Query>;

class QueryCache extends Subscribable<QueryCacheListener> {
  List<Query> _queries;
  QueryHashMap _queriesMap;

  QueryCacheOnError? onError;
  QueryCacheOnData? onData;

  QueryCache({
    this.onData,
    this.onError,
  })  : _queries = [],
        _queriesMap = {},
        super();

  Query<TQueryFnData, TError, TData> build<TQueryFnData, TError, TData>(
      QueryClient client, QueryOptions<TQueryFnData, TError, TData> options,
      [QueryState<TData, TError>? state]) {
    QueryKey queryKey = options.queryKey!;
    String queryHash =
        options.queryHash ?? hashQueryKeyByOptions(queryKey, options);
    Query<TQueryFnData, TError, TData>? query =
        get<TQueryFnData, TError, TData>(queryHash);

    if (query == null) {
      query = Query(
        cache: this,
        queryKey: queryKey,
        queryHash: queryHash,
        options: client.defaultQueryOptions(options),
        state: state,
        defaultOptions: client.getQueryDefaults(queryKey),
        meta: options.meta,
      );
      add(query);
    }
    return query;
  }

  void add(Query query) {
    if (!_queriesMap.containsKey(query.queryHash)) {
      _queriesMap[query.queryHash] = query;
      _queries.add(query);
      notify(
        QueryCacheNotifyEvent(
          QueryCacheNotifyEventType.queryAdded,
          query,
        ),
      );
    }
  }

  void remove(Query query) {
    Query? queryInMap = _queriesMap[query.queryHash];
    if (queryInMap == null) return;
    query.destroy();
    _queries = _queries.where((x) => x != query).toList();
    if (queryInMap == query) {
      _queriesMap.remove(query.queryHash);
    }
    notify(QueryCacheNotifyEvent(
      QueryCacheNotifyEventType.queryRemoved,
      query,
    ));
  }

  void clear() {
    notifyManager.batch(() {
      for (var query in _queries) {
        remove(query);
      }
    });
  }

  Query<TQueryFnData, TError, TData>? get<TQueryFnData, TError, TData>(
      String queryHash) {
    return _queriesMap[queryHash] as Query<TQueryFnData, TError, TData>?;
  }

  List<Query> getAll() {
    return _queries;
  }

  Query? find<TQueryFnData, TError, TData>(
    QueryKey queryKey,
    QueryFilters queryFilters,
  ) {
    queryFilters.exact ??= true;
    return _queries
        .firstWhereOrNull((query) => matchQuery(queryFilters, query));
  }

  List<Query> findAll(QueryKey? queryKey, [QueryFilters? filters]) {
    if (queryKey == null && filters == null)
      throw Exception(
          "[QueryCache.findAll] both `queryKey` & `filters` can't be null");
    bool filterIsEmpty =
        filters?.toJson().entries.every((map) => map.value == null) ?? false;
    return filterIsEmpty
        ? _queries
        : _queries.where((query) => matchQuery(filters!, query)).toList();
  }

  void notify(QueryCacheNotifyEvent event) {
    notifyManager.batch(() {
      for (var listener in listeners) {
        listener(event);
      }
    });
  }

  @override
  void onSubscribe() {}

  @override
  void onUnsubscribe() {}

  /// Dummy function just to keep the API similar to react-query
  void onFocus() {}

  void onOnline() {
    notifyManager.batch(() {
      _queries.forEach((query) {
        query.onOnline();
      });
    });
  }
}