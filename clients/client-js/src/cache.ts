import { LRUCache } from 'lru-cache'

export class Cache {

    private cacheImpl: LRUCache<string, string, any>;

    private static readonly MAX_SIZE = 100;
    private static readonly DEFAULT_MAX_ELEMENTS = 500;
    private static readonly DEFAULT_TTL_MINUTES = 10;
    private static readonly MINUTE_IN_MILLIS = 60_000;

    /**
     * 
     * @param maxElementsSize count of max elements in cache
     * @param maxElementTtl 
     */
    constructor(maxElementsSize: number = Cache.DEFAULT_MAX_ELEMENTS, maxElementTtl: number = Cache.DEFAULT_TTL_MINUTES) {

        const options = {
            max: maxElementsSize,

            // a safe limit on the maximum storage consumed
            maxSize: Cache.MAX_SIZE,
            sizeCalculation: (_value, _key) => {
                return 1
            },

            // for use when you need to clean up something when objects
            // are evicted from the cache
            dispose: (_value, _key) => { },

            // how long to live in ms
            ttl: Cache.MINUTE_IN_MILLIS * maxElementTtl,

            // return stale items before removing from cache?
            allowStale: false,
            noUpdateTTL: true,
            updateAgeOnGet: false,
            updateAgeOnHas: false,

            // async method to use for cache.fetch(), for
            // stale-while-revalidate type of behavior _other -> { options, signal, context }
            fetchMethod: async (_key, _staleValue, _other) => { },
        }

        this.cacheImpl = new LRUCache(options);
    }

    public save(key: string, element: any): void {
        this.cacheImpl.set(key, element);
    }

    public get(key: string): any {
        return this.cacheImpl.get(key, { updateAgeOnGet: false, allowStale: false })
    }
}
