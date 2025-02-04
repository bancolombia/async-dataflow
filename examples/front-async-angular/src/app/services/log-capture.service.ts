import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class LogCaptureService {
  private logsSubject: BehaviorSubject<string[]> = new BehaviorSubject<string[]>([]);
  private logs: string[] = [];

  constructor() {
    // Wrap the console.log method
    this.wrap('log');
    this.wrap('info');
    this.wrap('debug');
    this.wrap('error');
    this.wrap('warn');
  }

  private wrap(fn: any) {
    // Save the original console.log method
    const cons: any = console;
    const originalConsoleLog = cons[fn];

    // Override console.log to capture logs
    cons[fn] = (...args: any[]) => {
      // Convert the arguments to a string (can also JSON.stringify if needed)
      const logMessage = args.map(arg => (typeof arg === 'object' ? JSON.stringify(arg) : arg)).join(' ');

      // Push the log message to the logs array
      this.logs.push(logMessage);

      // Emit the new logs array to the BehaviorSubject
      this.logsSubject.next(this.logs);

      // Call the original console.log (to still show logs in the console)
      originalConsoleLog(...args);
    };
  }

  // Get the observable stream of logs
  getLogs$() {
    return this.logsSubject.asObservable();
  }
}
