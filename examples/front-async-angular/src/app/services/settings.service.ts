import { Injectable } from '@angular/core';
import { Settings } from '../models/settings.interface';
import { BehaviorSubject } from 'rxjs';

const SETTINGS = 'settings';
@Injectable({
  providedIn: 'root'
})
export class SettingsService {
  settingsSubject: BehaviorSubject<Settings>;

  constructor() {
    this.settingsSubject = new BehaviorSubject<Settings>(this.load());
  }

  public load(): Settings {
    const settings = localStorage.getItem(SETTINGS);
    if (settings) {
      const parsed = JSON.parse(settings);
      if (parsed.heartbeatDelay && parsed.maxRetries && parsed.defaultRequestDelay && parsed.transports) {
        return parsed;
      }
    }
    return {
      heartbeatDelay: 5000,
      maxRetries: 10,
      defaultRequestDelay: 1000,
      transports: ['ws', 'sse']
    };
  }

  public save(settings: Settings) {
    localStorage.setItem(SETTINGS, JSON.stringify(settings));
    this.settingsSubject.next(settings);
  }
}
