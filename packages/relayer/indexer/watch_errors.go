package indexer

import log "github.com/sirupsen/logrus"

func (svc *Service) watchErrors() {
	// nolint: gosimple
	for {
		select {
		case err := <-svc.errChan:
			log.Errorf("svc.watchErrors: %v", err)
		}
	}
}
