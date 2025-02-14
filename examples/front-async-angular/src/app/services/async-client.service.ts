import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { AsyncClient } from '@bancolombia/chanjs-client';
import { Subject } from 'rxjs';
import { Message } from '../models/message.inteface';
import { environment } from '../environments/environment';
import { SettingsService } from './settings.service';
import { U } from '@angular/cdk/keycodes';

@Injectable({
  providedIn: 'root',
})
export class AsyncClientService {
  private getEventFromAsyncDataflow = new Subject<Message>();
  public eventRecived$ = this.getEventFromAsyncDataflow.asObservable();
  private client?: AsyncClient;
  private channel_ref: string = '';
  constructor(private http: HttpClient, private settingsProvider: SettingsService) { }

  public getCredentials(user_ref: string) {
    const settings = this.settingsProvider.load();
    let url = `${environment.servers[settings.server].api_business}/credentials`;
    if (location.protocol === 'https:') {
      console.log('Try using secure protocol to generate credentials');
      url = url.replace('http://', 'https://');
      url = url.replace('ws://', 'wss://');
    }

    this.http
      .get(url, { params: { user_ref: user_ref } })
      .subscribe((res: any) => {
        this.channel_ref = res.channelRef;
        this.createChannel(res);
      });
  }

  public connected(): boolean {
    return this.client?.connected() || false;
  }

  private createChannel(res: any) {
    this.initChannel(res.channelRef, res.channelSecret);
  }

  private initChannel(channel_ref: string, channel_secret: string) {
    console.log('Opening web socket with channel_ref:', channel_ref);
    const settings = this.settingsProvider.load();
    let url = environment.servers[settings.server].socket_url_async;
    if (location.protocol === 'https:') {
      console.log('Try using secure protocol to open channel');
      url = url.replace('http://', 'https://');
      url = url.replace('ws://', 'wss://');
    }

    this.client = new AsyncClient({
      socket_url: url,
      channel_ref,
      channel_secret,
      heartbeat_interval: settings.heartbeatDelay,
      maxReconnectAttempts: settings.maxRetries
    }, settings.transports);

    this.client.connect();
    this.listenEvents(this.client);
  }

  private listenEvents(client: AsyncClient) {
    client.listenEvent('businessEvent', (message) => {
      this.getEventFromAsyncDataflow.next(message);
    });
    client.listenEvent('ch-ms-async-callback.svp.reply', (message) => {
      this.getEventFromAsyncDataflow.next(message);
    });
  }

  public closeChannel() {
    this.client?.disconnect();
  }

  public forceConnect() {
    return this.client?.connect();
  }

  public getRef() {
    return this.channel_ref;
  }
}
