package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	"github.com/gofrs/flock"
	"github.com/kukusuyi/Questrace/backend/internal/app"
	"github.com/kukusuyi/Questrace/backend/internal/config"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "Questrace:", err)
		os.Exit(1)
	}
}
func run() error {
	dir := flag.String("data-dir", "", "Data directory")
	port := flag.Int("port", 8080, "HTTP port (0 selects a free port)")
	host := flag.String("host", "0.0.0.0", "Listening interface")
	parent := flag.Bool("parent-stdio", false, "Exit when parent closes stdin")
	backup := flag.String("backup", "", "Export offline backup archive and exit")
	restore := flag.String("restore", "", "Restore offline backup archive and exit")
	flag.Parse()
	var err error
	// An explicit --data-dir wins; then the environment; then the platform data
	// directory, which reuses a pre-rename Notebook directory in place.
	if *dir, err = config.SelectDataDir(*dir); err != nil {
		return err
	}
	if *dir, err = filepath.Abs(*dir); err != nil {
		return err
	}
	if err = os.MkdirAll(*dir, 0700); err != nil {
		return err
	}
	// Outside the data directory so restore can safely replace the directory.
	lock := flock.New(*dir + ".lock")
	ok, err := lock.TryLock()
	if err != nil {
		return err
	}
	if !ok {
		return fmt.Errorf("此数据目录已有 Questrace 进程运行")
	}
	defer lock.Unlock()
	if *backup != "" {
		return app.Backup(*dir, *backup)
	}
	if *restore != "" {
		return app.Restore(*dir, *restore)
	}
	cfg, err := config.LoadLocal(*dir)
	if err != nil {
		return err
	}
	logFile, err := os.OpenFile(filepath.Join(*dir, "questrace.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer logFile.Close()
	logger := slog.New(slog.NewJSONHandler(io.MultiWriter(os.Stderr, logFile), nil))
	rt, err := app.NewLocal(cfg, logger)
	if err != nil {
		return err
	}
	defer rt.DB.Close()
	explicit := false
	flag.Visit(func(f *flag.Flag) {
		if f.Name == "port" {
			explicit = true
		}
	})
	listener, err := net.Listen("tcp", net.JoinHostPort(*host, strconv.Itoa(*port)))
	if err != nil && !explicit {
		listener, err = net.Listen("tcp", net.JoinHostPort(*host, "0"))
	}
	if err != nil {
		return fmt.Errorf("无法监听端口: %w", err)
	}
	actual := listener.Addr().(*net.TCPAddr).Port
	local := fmt.Sprintf("http://127.0.0.1:%d", actual)
	rt.AddressList = func() []string { return app.Addresses(*host, actual) }
	rt.URLs = rt.AddressList()
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	if *parent {
		go func() { _, _ = io.Copy(io.Discard, os.Stdin); cancel() }()
	}
	done := make(chan struct{})
	go func() { defer close(done); rt.RunWorker(ctx) }()
	server := &http.Server{Handler: rt, ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 60 * time.Second}
	stopped := make(chan struct{})
	go func() {
		defer close(stopped)
		<-ctx.Done()
		shutdown, c := context.WithTimeout(context.Background(), 10*time.Second)
		defer c()
		_ = server.Shutdown(shutdown)
	}()
	ready := map[string]any{"event": "ready", "url": local, "urls": rt.URLs, "data_dir": *dir, "log": logFile.Name(), "version": "2.0.0"}
	if rt.NeedsSetup() {
		ready["setup_token"] = cfg.SetupToken
	}
	_ = json.NewEncoder(os.Stdout).Encode(ready)
	err = server.Serve(listener)
	cancel()
	<-stopped
	<-done
	if err == http.ErrServerClosed {
		return nil
	}
	return err
}
