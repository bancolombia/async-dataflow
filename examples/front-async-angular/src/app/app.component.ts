import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { AsyncClientService } from '../app/services/async-client.service';
import { BusinessService } from '../app/services/business.service';
import { RouterOutlet } from '@angular/router';
import { HttpClientModule } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { LogCaptureService } from './services/log-capture.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, HttpClientModule, CommonModule, FormsModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent implements OnInit, OnDestroy {
  title = 'front-async';
  delay = 5000;
  user_ref = 'UNIQUEID';
  results: string[] = [];
  private eventReceived?: Subscription;
  logs: string[] = [];
  private logsSubscription?: Subscription;

  constructor(
    private asyncClientService: AsyncClientService,
    private businessService: BusinessService,
    private logCaptureService: LogCaptureService
  ) { }

  ngOnInit(): void {
    this.connect();
    this.logsSubscription = this.logCaptureService.getLogs$().subscribe(logs => {
      this.logs = logs;
    });
  }

  ngOnDestroy() {
    // Unsubscribe to prevent memory leaks
    if (this.logsSubscription) {
      this.logsSubscription.unsubscribe();
    }
    if (this.eventReceived) {
      this.eventReceived.unsubscribe();
    }
  }

  connect() {
    this.disconnect();
    this.asyncClientService.getCredentials(this.user_ref);
    this.listenEvents();
  }

  reconnect() {
    this.asyncClientService.forceConnect();
  }

  disconnect() {
    this.asyncClientService.closeChannel();
  }

  generateRequest() {
    let start = performance.now();
    this.businessService
      .callBusinessUseCase(this.delay)
      .subscribe((_res: any) => {
        this.results.push(
          `Get empty response after ${performance.now() - start} ms`
        );
      });
  }

  private listenEvents() {
    if (!this.eventReceived) {
      this.eventReceived = this.asyncClientService.eventRecived$.subscribe(
        (msg) => {
          if (msg.event == 'businessEvent') {
            this.results.push(
              `Message from async dataflow, title: ${msg.payload.title} detail: ${msg.payload.detail}`
            );
          }
        }
      );
    }
  }
}