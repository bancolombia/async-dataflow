import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { HttpClientModule } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { v4 } from 'uuid';
import { MatIconModule } from '@angular/material/icon';
import { MatListModule } from '@angular/material/list';
import { AsyncClientService } from '../../services/async-client.service';
import { BusinessService } from '../../services/business.service';
import { Log } from '../../models/log.interface';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatCardModule } from '@angular/material/card';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { SettingsService } from '../../services/settings.service';
import { Settings } from '../../models/settings.interface';


@Component({
  selector: 'app-requests',
  standalone: true,
  imports: [CommonModule, FormsModule, HttpClientModule, MatListModule, MatIconModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatCardModule, MatSnackBarModule],
  templateUrl: './requests.component.html',
  styleUrl: './requests.component.css'
})
export class RequestsComponent implements OnInit, OnDestroy {
  title = 'front-async';
  delay = 5000;
  settings?: Settings;
  results: Array<Log> = [];
  private eventReceived?: Subscription;
  private user_ref: string;

  constructor(
    private asyncClientService: AsyncClientService,
    private businessService: BusinessService,
    private settingsProvider: SettingsService,
    private snackbar: MatSnackBar
  ) {
    this.user_ref = v4();
  }

  ngOnInit(): void {
    this.updateSettings(this.settingsProvider.load());
    this.settingsProvider.settingsSubject.subscribe((settings: Settings) => this.updateSettings(settings));
    this.connect();
    this.listenEvents();
  }

  ngOnDestroy() {
    if (this.eventReceived) {
      this.eventReceived.unsubscribe();
    }
  }

  connect() {
    this.disconnect();
    this.asyncClientService.getCredentials(this.user_ref);
  }

  reconnect() {
    this.asyncClientService.forceConnect();
  }

  disconnect() {
    this.user_ref = v4();
    this.asyncClientService.closeChannel();
  }

  connected() {
    return this.asyncClientService.connected();
  }

  cleanRequests() {
    this.results = [];
  }

  generateRequest() {
    let start = performance.now();
    this.businessService
      .callBusinessUseCase(this.delay, this.user_ref)
      .subscribe((_res: any) => {
        this.results.unshift({ message: `${this.dateNow()} Get empty response after ${performance.now() - start} ms`, type: 'out' });
      });
  }

  copyToClipboard() {
    navigator.clipboard.writeText(JSON.stringify(this.results));
    this.snackbar.open('Requests copied to clipboard', 'Close', { duration: 2000 });
  }

  private listenEvents() {
    if (!this.eventReceived) {
      this.eventReceived = this.asyncClientService.eventRecived$.subscribe(
        (msg) => {
          if (msg.event == 'businessEvent') {
            this.results.unshift(
              { message: `${this.dateNow()} Message from async dataflow, title: ${msg.payload.title} detail: ${msg.payload.detail}`, type: 'in' }
            );
          }
          if (msg.event == 'ch-ms-async-callback.svp.reply') {
            this.results.unshift(
              { message: `${this.dateNow()} Message from async dataflow bridge, title: ${msg.payload.data.reply.messageData.title} detail: ${msg.payload.data.reply.messageData.detail}`, type: 'in' }
            );
          }
        }
      );
    }
  }

  private dateNow() {
    return new Date().toISOString();
  }

  private updateSettings(settings: Settings) {
    this.settings = settings;
    this.delay = this.settings.defaultRequestDelay;
  }
}