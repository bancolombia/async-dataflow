import { LRUCache } from 'lru-cache'

export class Cache {

    private cacheImpl: LRUCache<string, string, any>; 

    constructor(
        private maxElementsSize: number = 500,
        private maxElementTtl: number = 10) {

        const options = {
            max: maxElementsSize,
        
            // for use with tracking overall storage size
            maxSize: 100,
            sizeCalculation: (value, key) => {
                return 1
            },
        
            // for use when you need to clean up something when objects
            // are evicted from the cache
            dispose: (value, key) => {},
        
            // how long to live in ms
            ttl: 1000 * 60 * maxElementTtl,
    
            // return stale items before removing from cache?
            allowStale: false,
            noUpdateTTL: true,
            updateAgeOnGet: false,
            updateAgeOnHas: false,
        
            // async method to use for cache.fetch(), for
            // stale-while-revalidate type of behavior
            fetchMethod: async (
                key,
                staleValue,
                { options, signal, context }
            ) => {},
        }
        
        this.cacheImpl = new LRUCache(options);
    }

    public save(key: string, element: any): void {
        this.cacheImpl.set(key, element);
    }

    public get(key: string): any {
        return this.cacheImpl.get(key, {updateAgeOnGet: false, allowStale: false})
    }
}
