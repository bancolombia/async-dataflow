import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { AsyncClient } from 'chanjs-client';
import { Subject } from 'rxjs';
import { environment } from 'src/environments/environment';
import { Message } from '../models/message.inteface';

@Injectable({
  providedIn: 'root',
})
export class AsyncClientService {
  private getEventFromAsyncDataflow = new Subject<Message>();
  public eventRecived$ = this.getEventFromAsyncDataflow.asObservable();
  private client;
  constructor(private http: HttpClient) {}

  public getCredentials(user_ref) {
    if (this.hasChannelCreated()) {
      this.initChannel(
        sessionStorage.getItem('channel_ref'),
        sessionStorage.getItem('channel_secret')
      );
    } else {
      const url = `${environment.api_business}/credentials`;

      this.http
        .get(url, { params: { user_ref: user_ref } })
        .subscribe((res: any) => {
          sessionStorage.setItem('channel_ref', res.channelRef);
          sessionStorage.setItem('channel_secret', res.channelSecret);
          this.createChannel(res);
        });
    }
  }
  private hasChannelCreated() {
    return (
      sessionStorage.getItem('channel_ref') &&
      sessionStorage.getItem('channel_secret') != null
    );
  }

  private createChannel(res: any) {
    this.initChannel(res.channelRef, res.channelSecret);
  }

  private initChannel(channel_ref, channel_secret) {
    this.client = new AsyncClient({
      socket_url: `ws://${environment.socket_url_async}/ext/socket`,
      channel_ref,
      channel_secret,
      heartbeat_interval: environment.heartbeat_interval,
    });

    this.client.connect();
    this.listenEvents(this.client);
  }

  private listenEvents(client) {
    client.listenEvent('businessEvent', (message) => {
      this.getEventFromAsyncDataflow.next(message);
    });
  }

  public closeChannel() {
    sessionStorage.removeItem('channel_ref');
    sessionStorage.removeItem('channel_secret');
    this.client.disconnect();
  }
}
