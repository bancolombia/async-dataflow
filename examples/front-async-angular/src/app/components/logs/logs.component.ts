import { Component, OnDestroy, OnInit } from '@angular/core';
import { LogCaptureService } from '../../services/log-capture.service';
import { Log } from '../../models/log.interface';
import { Subscription } from 'rxjs';
import { CommonModule } from '@angular/common';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';

@Component({
  selector: 'app-logs',
  standalone: true,
  imports: [CommonModule, MatIconModule, MatButtonModule, MatCardModule, MatSnackBarModule],
  templateUrl: './logs.component.html',
  styleUrl: './logs.component.css'
})
export class LogsComponent implements OnInit, OnDestroy {
  logs: Log[] = [];
  private logsSubscription?: Subscription;

  constructor(public logCaptureService: LogCaptureService, private snackbar: MatSnackBar) {
  }

  ngOnInit(): void {
    this.logsSubscription = this.logCaptureService.getLogs$().subscribe(logs => {
      this.logs = logs;
    });
  }

  ngOnDestroy(): void {
    if (this.logsSubscription) {
      this.logsSubscription.unsubscribe();
    }
  }


  copyToClipboard() {
    navigator.clipboard.writeText(JSON.stringify(this.logs));
    this.snackbar.open('Requests copied to clipboard', 'Close', { duration: 2000 });
  }

}
