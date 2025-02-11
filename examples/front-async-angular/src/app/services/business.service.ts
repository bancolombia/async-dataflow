import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { environment } from '../environments/environment';
import { AsyncClientService } from './async-client.service';
import { SettingsService } from './settings.service';

@Injectable({
  providedIn: 'root',
})
export class BusinessService {
  constructor(private http: HttpClient, private channel: AsyncClientService, private settingsProvider: SettingsService) { }

  public callBusinessUseCase(delay: number, user_ref: string) {
    const settings = this.settingsProvider.load();
    let url = `${environment.servers[settings.server].api_business}/business`;
    if (location.protocol === 'https:') {
      console.log('Try using secure protocol to call backend');
      url = url.replace('http://', 'https://');
      url = url.replace('ws://', 'wss://');
    }
    let httpParams = new HttpParams()
      .set('channel_ref', this.channel.getRef())
      .set('user_ref', user_ref)
      .set('delay', delay);
    return this.http.get(url, {
      params: httpParams,
    });
  }
}
