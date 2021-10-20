
export class Utils{

    public static jitter(baseTime : number, randomFactor : number) : number{
        const rest = baseTime * randomFactor
        return (baseTime - rest) + Math.random() * rest;
    }

    public static expBackoff(initial: number, max: number, actualRetry: number, jitterFn: Function = (x) => x){
        const base = initial * Math.pow(2, actualRetry);
        if (base > max){
            return jitterFn(max)
        }else {
            return jitterFn(base);
        }
    }
}
