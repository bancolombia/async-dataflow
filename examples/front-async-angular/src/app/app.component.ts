import { Component, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { AsyncClientService } from './services/async-client.service';
import { BusinessService } from './services/business.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
})
export class AppComponent implements OnInit {
  title = 'front-async';
  delay = 5000;
  user_ref = 'UNIQUEID';
  results = [];
  private eventRecived: Subscription = null;

  constructor(
    private asyncClientService: AsyncClientService,
    private businessService: BusinessService
  ) {}

  ngOnInit(): void {
    this.asyncClientService.getCredentials(this.user_ref);
    this.listenEvents();
  }
  generateRequest() {
    let start = performance.now();
    this.businessService
      .callBusinessUseCase(this.delay)
      .subscribe((res: any) => {
        this.results.push(
          `Get empty response after ${performance.now() - start} ms`
        );
      });
  }

  private listenEvents() {
    this.eventRecived = this.asyncClientService.eventRecived$.subscribe(
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
