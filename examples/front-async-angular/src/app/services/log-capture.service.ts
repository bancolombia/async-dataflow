import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';
import { Log } from '../models/log.interface';

@Injectable({
  providedIn: 'root',
})
export class LogCaptureService {
  private logsSubject: BehaviorSubject<Log[]> = new BehaviorSubject<Log[]>([]);
  private logs: Log[] = [];

  constructor() {
    // Wrap the console.log method
    this.wrap('log');
    this.wrap('info');
    this.wrap('debug');
    this.wrap('error');
    this.wrap('warn');
  }

  public clearLogs() {
    this.logs = [];
    this.logsSubject.next(this.logs);
  }

  private wrap(fn: any) {
    // Save the original console.log method
    const cons: any = console;
    const originalConsoleLog = cons[fn];

    // Override console.log to capture logs
    cons[fn] = (...args: any[]) => {
      // Convert the arguments to a string (can also JSON.stringify if needed)
      const logMessage = (new Date().toISOString()) + ' -> ' + args.map(arg => (typeof arg === 'object' ? JSON.stringify(arg) : arg)).join(' ');
      const log: Log = { type: fn, message: logMessage };

      // Push the log message to the logs array
      this.logs.unshift(log);

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
